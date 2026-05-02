import SwiftData
import SwiftUI

extension PopoverContentView {
  func captureForm(mode: CaptureWindowView.Mode) -> some View {
    CaptureWindowView(
      mode: mode,
      onSave: { result in
        let didSave: Bool =
          switch mode {
          case .create:
            saveCapture(result)
          case .edit(let capture):
            updateCapture(capture, with: result)
          }
        guard didSave else { return false }
        route = .root
        showPosted = false
        showToast(mode.isCreate ? "Draft saved" : "Draft updated")
        return true
      },
      onCancel: { route = .root }
    )
    .modelContainer(modelContext.container)
  }

  func postHandoff(_ capture: Capture) -> some View {
    PostHandoffView(
      capture: capture,
      checklistItems: postingChecklistItems(for: capture),
      onCopyTitle: { copyPostTitle(for: capture) },
      onCopyBody: { copyPostBody(for: capture) },
      onCopyLinks: { copyPostLinks(for: capture) },
      onCopyAll: { copyPostHandoffText(for: capture) },
      onOpenSubmit: { openRedditSubmitPage(for: capture) },
      onMarkPosted: { markCaptureAsPosted(capture) },
      onClose: { route = .root },
      onMarkSubredditPosted: { subredditId in
        capture.markSubredditAsPosted(subredditId)
        do { try modelContext.save() } catch {
          NSLog("RedditReminder: mark subreddit posted failed: \(error)")
          modelContext.rollback()
        }
        onAppStateChanged()
      },
      onMarkSubredditUnposted: { subredditId in
        capture.markSubredditAsUnposted(subredditId)
        do { try modelContext.save() } catch {
          NSLog("RedditReminder: unmark subreddit posted failed: \(error)")
          modelContext.rollback()
        }
        onAppStateChanged()
      }
    )
  }

  func detailScreen<Content: View>(
    title: String,
    systemName: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Button(action: { route = .root }) {
          Image(systemName: "chevron.left")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help("Back")
        .accessibilityLabel("Back")

        Image(systemName: systemName)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AppColors.redditOrange)

        Text(title)
          .font(.system(size: 13, weight: .semibold))

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .overlay(alignment: .bottom) { Divider() }

      content()
    }
  }

  func handlePendingMenuRequests() {
    handleNewCaptureRequest()
    handlePreferencesRequest()
  }

  func handleNewCaptureRequest() {
    guard menuBarController.newCaptureRequestCount > handledNewCaptureRequestCount else { return }
    handledNewCaptureRequestCount = menuBarController.newCaptureRequestCount
    route = .captureCreate
    showPosted = false
  }

  func handlePreferencesRequest() {
    guard menuBarController.preferencesRequestCount > handledPreferencesRequestCount else { return }
    handledPreferencesRequestCount = menuBarController.preferencesRequestCount
    route = .preferences
  }
}

extension CaptureWindowView.Mode {
  fileprivate var isCreate: Bool {
    if case .create = self { return true }
    return false
  }
}
