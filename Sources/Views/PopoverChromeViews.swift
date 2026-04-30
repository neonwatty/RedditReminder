import SwiftUI

struct PopoverToastView: View {
  let message: String

  var body: some View {
    Text(message)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(AppColors.redditOrange.opacity(0.9))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.top, 48)
      .transition(.move(edge: .top).combined(with: .opacity))
  }
}

struct PopoverHeaderView: View {
  nonisolated static let settingsButtonTitle = "Settings"
  nonisolated static let preferencesAccessibilityLabel = "Open preferences"
  nonisolated static let newCaptureAccessibilityLabel = "New capture"
  nonisolated static let queueToggleAccessibilityIdentifier = "popover.header.queue"
  nonisolated static let postedToggleAccessibilityIdentifier = "popover.header.posted"

  @Binding var showPosted: Bool
  let onOpenPreferences: () -> Void
  let onNewCapture: () -> Void

  var body: some View {
    HStack {
      Text("RedditReminder")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.primary)
      Spacer()
      HStack(spacing: 2) {
        toggleButton(
          "Queue",
          active: !showPosted,
          identifier: Self.queueToggleAccessibilityIdentifier
        ) { showPosted = false }
        toggleButton(
          "Posted",
          active: showPosted,
          identifier: Self.postedToggleAccessibilityIdentifier
        ) { showPosted = true }
      }
      Spacer()
      Button(action: onOpenPreferences) {
        Label(Self.settingsButtonTitle, systemImage: "gearshape")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help(Self.preferencesAccessibilityLabel)
      .accessibilityLabel(Self.preferencesAccessibilityLabel)
      Button(action: onNewCapture) {
        Image(systemName: "plus").font(.system(size: 14, weight: .light))
          .foregroundStyle(AppColors.redditOrange)
      }
      .buttonStyle(.plain)
      .help(Self.newCaptureAccessibilityLabel)
      .accessibilityLabel(Self.newCaptureAccessibilityLabel)
      .padding(.leading, 8)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .overlay(alignment: .bottom) { Divider() }
  }

  private func toggleButton(
    _ title: String,
    active: Bool,
    identifier: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 10, weight: active ? .semibold : .medium))
        .foregroundStyle(active ? AppColors.redditOrange : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(active ? AppColors.redditOrange.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityIdentifier(identifier)
  }
}

struct PopoverSearchBarView: View {
  @Binding var searchText: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
      TextField("Search captures", text: $searchText)
        .font(.system(size: 11))
        .textFieldStyle(.plain)
      if !searchText.isEmpty {
        Button(action: { searchText = "" }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(.quaternary.opacity(0.25))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .overlay(alignment: .bottom) { Divider() }
  }
}

struct PopoverFilterBarView: View {
  let subredditName: String?
  let onClear: () -> Void

  var body: some View {
    HStack {
      if let subredditName {
        Text("Filtered: \(subredditName)")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(AppColors.redditOrange)
      }
      Spacer()
      Button("Show all", action: onClear)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .background(AppColors.redditOrange.opacity(0.06))
    .overlay(alignment: .bottom) { Divider() }
  }
}

struct PopoverFooterView: View {
  let text: String

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      Text(text)
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }
  }
}
