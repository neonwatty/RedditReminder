import AppKit
import SwiftData

#if DEBUG
  extension AppDelegate {
    static let qaTestCaptureTitle = "QA Workflow Capture"
    static let qaTestCaptureText = "Created by RedditReminder automated QA."
    static let qaTestCaptureLink = "https://example.com/reddit-reminder-qa"

    @discardableResult
    func qaCreateTestCapture() -> Bool {
      guard let container = modelContainer else { return false }
      let context = container.mainContext

      do {
        let subreddits = try context.fetch(FetchDescriptor<Subreddit>())
        let subreddit =
          subreddits.first { $0.name.caseInsensitiveCompare("r/SideProject") == .orderedSame }
          ?? subreddits.sorted { $0.sortOrder < $1.sortOrder }.first
        guard let subreddit else { return false }

        let capture = Capture(
          title: Self.qaTestCaptureTitle,
          text: Self.qaTestCaptureText,
          links: [Self.qaTestCaptureLink],
          subreddits: [subreddit]
        )
        context.insert(capture)
        try context.save()
        runRefreshCycle()
        return true
      } catch {
        context.rollback()
        NSLog("RedditReminder: QA create test capture failed: \(error)")
        return false
      }
    }

    @discardableResult
    func qaDeleteTestCaptures() -> Bool {
      guard let container = modelContainer else { return false }
      let context = container.mainContext

      do {
        let captures = try context.fetch(FetchDescriptor<Capture>())
        let testCaptures = captures.filter { $0.title == Self.qaTestCaptureTitle }
        guard !testCaptures.isEmpty else { return true }

        menuBarController.closePostHandoffWindow()
        menuBarController.dismissPopover()

        for capture in testCaptures {
          context.delete(capture)
        }
        try context.save()
        runRefreshCycle()
        return true
      } catch {
        context.rollback()
        NSLog("RedditReminder: QA delete test captures failed: \(error)")
        return false
      }
    }

    @discardableResult
    func qaCopyFirstQueuedCaptureTitle(to pasteboard: any PasteboardWriting = NSPasteboard.general)
      -> Bool
    {
      guard
        let title = qaFirstQueuedCapture()?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
        !title.isEmpty
      else { return false }
      return RedditPostingActions.copyText(title, to: pasteboard)
    }

    @discardableResult
    func qaCopyFirstQueuedCapture(to pasteboard: any PasteboardWriting = NSPasteboard.general)
      -> Bool
    {
      guard let capture = qaFirstQueuedCapture() else { return false }
      let text = RedditPostingActions.clipboardText(for: capture)
      guard !text.isEmpty else { return false }
      return RedditPostingActions.copyText(text, to: pasteboard)
    }

    @discardableResult
    func qaCopyFirstQueuedSubmitURL(to pasteboard: any PasteboardWriting = NSPasteboard.general)
      -> Bool
    {
      guard let capture = qaFirstQueuedCapture(),
        let url = RedditPostingActions.submitURL(for: capture)
      else { return false }
      return RedditPostingActions.copyText(url.absoluteString, to: pasteboard)
    }

    @discardableResult
    func qaMarkFirstQueuedCapturePosted() -> Bool {
      guard let container = modelContainer,
        let capture = qaFirstQueuedCapture()
      else { return false }

      capture.markAsPosted()
      do {
        try container.mainContext.save()
        runRefreshCycle()
        return true
      } catch {
        container.mainContext.rollback()
        NSLog("RedditReminder: QA mark posted failed: \(error)")
        return false
      }
    }

    func qaFirstQueuedCapture() -> Capture? {
      guard let container = modelContainer else { return nil }

      do {
        let captures = try container.mainContext.fetch(FetchDescriptor<Capture>())
        return
          captures
          .filter { $0.status == .queued }
          .sorted { $0.createdAt > $1.createdAt }
          .first
      } catch {
        NSLog("RedditReminder: QA fetch first queued capture failed: \(error)")
        return nil
      }
    }
  }
#endif
