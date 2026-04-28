import SwiftUI

extension PopoverContentView {
  var emptyState: some View {
    OnboardingEmptyView(onNewCapture: openNewCapture)
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
