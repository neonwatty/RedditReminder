import AppKit
import SwiftUI

extension PopoverContentView {
  func openNewCapture() {
    openCaptureWindow(mode: .create)
  }

  func openCaptureForEditing(_ capture: Capture) {
    openCaptureWindow(mode: .edit(capture))
  }

  func openCaptureWindow(mode: CaptureWindowView.Mode) {
    let (title, successMsg): (String, String) =
      switch mode {
      case .create: ("New Capture", "Draft saved")
      case .edit: ("Edit Capture", "Draft updated")
      }
    let formView = CaptureWindowView(
      mode: mode,
      onSave: { result in
        let ok: Bool =
          switch mode {
          case .create: saveCapture(result)
          case .edit(let capture): updateCapture(capture, with: result)
          }
        if ok {
          menuBarController.closeCaptureWindow()
          showToastAfterReopen(successMsg)
        }
        return ok
      },
      onCancel: { menuBarController.closeCaptureWindow() }
    ).modelContainer(modelContext.container)
    menuBarController.showCaptureWindow(title: title, content: formView)
  }

  func openPreferences() {
    let prefsView = PreferencesView(
      notificationService: notificationService,
      heuristicsStore: heuristicsStore,
      onAppStateChanged: onAppStateChanged
    )
    .modelContainer(modelContext.container)
    menuBarController.showPreferencesWindow(content: prefsView)
  }

  func openPostHandoff(for capture: Capture) {
    let view = PostHandoffView(
      capture: capture,
      checklistItems: postingChecklistItems(for: capture),
      onCopyTitle: { copyPostTitle(for: capture) },
      onCopyBody: { copyPostBody(for: capture) },
      onCopyLinks: { copyPostLinks(for: capture) },
      onCopyAll: { copyPostHandoffText(for: capture) },
      onOpenSubmit: { openRedditSubmitPage(for: capture) },
      onMarkPosted: { markCaptureAsPosted(capture) },
      onClose: { menuBarController.closePostHandoffWindow() }
    )
    menuBarController.showPostHandoffWindow(title: handoffWindowTitle(for: capture), content: view)
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
      showToastAfterReopen("Failed to mark as posted")
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
      showToast(emptyMessage)
      return false
    }

    if RedditPostingActions.copyText(text) {
      showToast(successMessage)
      return true
    } else {
      showToast("Copy failed")
      return false
    }
  }

  func openRedditSubmitPage(for capture: Capture) {
    guard let url = RedditPostingActions.submitURL(for: capture) else {
      showToast("No subreddit selected")
      return
    }

    let text = RedditPostingActions.clipboardText(for: capture)
    if !text.isEmpty {
      _ = RedditPostingActions.copyText(text)
    }

    if NSWorkspace.shared.open(url) {
      showToast("Copied text and opened Reddit")
    } else {
      showToast("Could not open Reddit")
    }
  }

  func openPostedURL(for capture: Capture) {
    guard
      let postedURL = capture.postedURL,
      let url = URL(string: postedURL),
      NSWorkspace.shared.open(url)
    else {
      showToast("Could not open posted link")
      return
    }
    showToast("Opened posted link")
  }

  func restoreCaptureToQueue(_ capture: Capture) {
    capture.markAsQueued()
    do { try modelContext.save() } catch {
      NSLog("RedditReminder: restore queued failed: \(error)")
      modelContext.rollback()
      showToastAfterReopen("Restore failed")
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
      showToastAfterReopen("Delete failed")
      return
    }
    showToastAfterReopen("Capture deleted")
  }

  func saveMediaFiles(_ urls: [URL], captureId: UUID) throws -> [String] {
    try CapturePersistenceActions.saveMediaFiles(urls, captureId: captureId, mediaStore: mediaStore)
  }

  func showToastAfterReopen(_ message: String) {
    menuBarController.openPopover()
    showToast(message, delay: .milliseconds(300))
  }

  func showToast(_ message: String, delay: Duration = .zero) {
    toastTask?.cancel()
    toastTask = Task {
      if delay > .zero {
        try? await Task.sleep(for: delay)
      }
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.2)) { toastMessage = message }
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.2)) { toastMessage = nil }
    }
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

  private func handoffWindowTitle(for capture: Capture) -> String {
    let title = RedditPostingActions.titleText(for: capture)
    return title.isEmpty ? "Post Handoff" : "Post Handoff: \(title)"
  }

  private func postingChecklistItems(for capture: Capture) -> [String] {
    capture.subreddits.flatMap { subreddit in
      cleanChecklistItems(subreddit.postingChecklist?.components(separatedBy: .newlines) ?? [])
    }
  }

  private func cleanChecklistItems(_ items: [String]) -> [String] {
    items
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
