import SwiftUI

enum QueueContentPresentation: Equatable {
  case onboarding
  case emptyWithWindows
  case filteredEmpty
  case list
}

extension PopoverContentView {
  nonisolated static let emptyQueueWithWindowsTitleText = "No captures queued"
  nonisolated static let emptyQueueWithWindowsDescriptionText =
    "Create a capture so your next posting windows have a draft ready."
  nonisolated static let emptyQueueWithWindowsButtonText = "Create capture"
  nonisolated static let emptyQueueWithWindowsButtonIdentifier = "queue.emptyWithWindows.createCapture"

  nonisolated static func queueContentPresentation(
    displayedCaptureCount: Int,
    upcomingWindowCount: Int,
    isFiltered: Bool
  ) -> QueueContentPresentation {
    if displayedCaptureCount > 0 {
      return .list
    }
    if isFiltered {
      return .filteredEmpty
    }
    if upcomingWindowCount > 0 {
      return .emptyWithWindows
    }
    return .onboarding
  }

  var emptyState: some View {
    OnboardingEmptyView(
      onSetupChannels: { openWorkspace(.channels) },
      onNewCapture: openNewCapture,
      onSetupNotifications: { openPreferences(tab: .notifications) }
    )
  }

  var emptyQueueWithWindowsState: some View {
    VStack(spacing: 10) {
      Image(systemName: "text.badge.plus")
        .font(.system(size: 20))
        .foregroundStyle(AppColors.redditOrange.opacity(0.75))
      Text(Self.emptyQueueWithWindowsTitleText)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.primary)
      Text(Self.emptyQueueWithWindowsDescriptionText)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button(Self.emptyQueueWithWindowsButtonText, action: openNewCapture)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppColors.redditOrange)
        .buttonStyle(.plain)
        .accessibilityIdentifier(Self.emptyQueueWithWindowsButtonIdentifier)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 28)
  }

  var filteredEmptyState: some View {
    VStack(spacing: 10) {
      Spacer()
      Image(systemName: "tray")
        .font(.system(size: 20))
        .foregroundStyle(.tertiary)
      Text("No captures for this subreddit")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      Button("+ New Capture", action: openNewCapture)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
        .buttonStyle(.plain)
      Spacer()
    }.frame(maxWidth: .infinity)
  }
}
