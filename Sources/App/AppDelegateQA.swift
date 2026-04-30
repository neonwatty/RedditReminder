import AppKit
import SwiftData

#if DEBUG
  extension AppDelegate {
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
