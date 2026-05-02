import AppKit
import SwiftUI

extension PopoverContentView {
  func openNewCapture() {
    route = .captureCreate
    showPosted = false
  }

  func openCaptureForEditing(_ capture: Capture) {
    route = .captureEdit(capture)
  }

  func openPreferences() {
    route = .preferences
  }

  func openPostHandoff(for capture: Capture) {
    route = .postHandoff(capture)
  }

  @discardableResult
  func saveCapture(_ result: CaptureFormResult) -> Bool {
    CapturePersistenceActions.saveCapture(
      result,
      modelContext: modelContext,
      mediaStore: mediaStore,
      onAppStateChanged: onAppStateChanged
    )
  }

  @discardableResult
  func updateCapture(_ capture: Capture, with r: CaptureFormResult) -> Bool {
    CapturePersistenceActions.updateCapture(
      capture,
      with: r,
      modelContext: modelContext,
      mediaStore: mediaStore,
      onAppStateChanged: onAppStateChanged
    )
  }

  func markCaptureAsPosted(_ capture: Capture) {
    let postedURLPrompt = promptForPostedURL()
    guard postedURLPrompt.accepted else { return }

    capture.markAsPosted(postedURL: postedURLPrompt.url)
    do { try modelContext.save() } catch {
      NSLog("RedditReminder: mark posted failed: \(error)")
      modelContext.rollback()
      showToastAfterReopen("Failed to mark as posted", style: .error)
      return
    }
    onAppStateChanged()
    showToastAfterReopen("Marked as posted")
  }

  @discardableResult
  func copyPostText(for capture: Capture) -> Bool {
    let text = RedditPostingActions.clipboardText(for: capture)
    return copyHandoffText(
      text, successMessage: "Post text copied", emptyMessage: "Nothing to copy")
  }

  @discardableResult
  func copyPostTitle(for capture: Capture) -> Bool {
    let title = RedditPostingActions.titleText(for: capture)
    return copyHandoffText(title, successMessage: "Title copied", emptyMessage: "No title to copy")
  }

  @discardableResult
  func copyPostBody(for capture: Capture) -> Bool {
    let body = capture.text.trimmingCharacters(in: .whitespacesAndNewlines)
    return copyHandoffText(body, successMessage: "Body copied", emptyMessage: "No body to copy")
  }

  @discardableResult
  func copyPostLinks(for capture: Capture) -> Bool {
    let links = RedditPostingActions.linksText(for: capture)
    return copyHandoffText(links, successMessage: "Links copied", emptyMessage: "No links to copy")
  }

  @discardableResult
  func copyPostHandoffText(for capture: Capture) -> Bool {
    let text = RedditPostingActions.handoffText(for: capture)
    return copyHandoffText(
      text,
      successMessage: "Post handoff copied",
      emptyMessage: "Nothing to copy"
    )
  }

  @discardableResult
  func copyHandoffText(_ text: String, successMessage: String, emptyMessage: String) -> Bool {
    guard !text.isEmpty else {
      showToast(emptyMessage, style: .error)
      return false
    }

    if RedditPostingActions.copyText(text) {
      showToast(successMessage)
      return true
    } else {
      showToast("Copy failed", style: .error)
      return false
    }
  }

  func openRedditSubmitPage(for capture: Capture) {
    guard let url = RedditPostingActions.submitURL(for: capture) else {
      showToast("No subreddit selected", style: .error)
      return
    }

    let text = RedditPostingActions.clipboardText(for: capture)
    if !text.isEmpty {
      _ = RedditPostingActions.copyText(text)
    }

    if NSWorkspace.shared.open(url) {
      showToast("Copied text and opened Reddit")
    } else {
      showToast("Could not open Reddit", style: .error)
    }
  }

  func openPostedURL(for capture: Capture) {
    guard
      let postedURL = capture.postedURL,
      let url = URL(string: postedURL),
      NSWorkspace.shared.open(url)
    else {
      showToast("Could not open posted link", style: .error)
      return
    }
    showToast("Opened posted link")
  }

  func restoreCaptureToQueue(_ capture: Capture) {
    capture.markAsQueued()
    do { try modelContext.save() } catch {
      NSLog("RedditReminder: restore queued failed: \(error)")
      modelContext.rollback()
      showToastAfterReopen("Restore failed", style: .error)
      return
    }
    onAppStateChanged()
    showToastAfterReopen("Moved back to queue")
  }

  func deleteCapture(_ capture: Capture) {
    guard confirmDelete(capture) else { return }

    do {
      try CapturePersistenceActions.deleteCapture(
        capture,
        modelContext: modelContext,
        mediaStore: mediaStore,
        onAppStateChanged: onAppStateChanged
      )
    } catch {
      showToastAfterReopen("Delete failed", style: .error)
      return
    }
    showToastAfterReopen("Capture deleted")
  }

  func saveMediaFiles(_ urls: [URL], captureId: UUID) throws -> [String] {
    try CapturePersistenceActions.saveMediaFiles(urls, captureId: captureId, mediaStore: mediaStore)
  }

  func showToast(_ message: String, style: ToastStyle = .success, delay: Duration = .zero) {
    toastTask?.cancel()
    toastTask = Task {
      if delay > .zero {
        try? await Task.sleep(for: delay)
      }
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.2)) { toast = Toast(message: message, style: style) }
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.2)) { toast = nil }
    }
  }

  func showToastAfterReopen(_ message: String, style: ToastStyle = .success) {
    menuBarController.openPopover()
    showToast(message, style: style, delay: .milliseconds(300))
  }

  private func promptForPostedURL() -> (accepted: Bool, url: String?) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Mark capture as posted?"
    alert.informativeText =
      "Optionally paste the Reddit post URL so posted history can reopen it later."
    alert.addButton(withTitle: "Mark Posted")
    alert.addButton(withTitle: "Cancel")

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
    field.placeholderString = "https://www.reddit.com/r/..."
    alert.accessoryView = field

    guard alert.runModal() == .alertFirstButtonReturn else { return (false, nil) }
    let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return (true, trimmed.isEmpty ? nil : trimmed)
  }

  private func confirmDelete(_ capture: Capture) -> Bool {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Delete this capture?"
    alert.informativeText =
      "This permanently removes the draft and any stored media. This cannot be undone."
    alert.addButton(withTitle: "Delete")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
  }

  func postingChecklistItems(for capture: Capture) -> [String] {
    capture.subreddits.flatMap { subreddit in
      PostingChecklistItems.cleaned(from: subreddit.postingChecklist)
    }
  }
}
