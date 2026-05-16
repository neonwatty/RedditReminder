import SwiftUI

enum ToastStyle {
  case success
  case error
}

struct Toast: Equatable {
  let message: String
  let style: ToastStyle
}

enum PopoverWorkspace: String, CaseIterable {
  case queue = "Queue"
  case planner = "Planner"
  case channels = "Channels"
  case projects = "Projects"
  case posted = "Posted"

  var iconName: String {
    switch self {
    case .queue: "tray"
    case .planner: "calendar"
    case .channels: "tag"
    case .projects: "folder"
    case .posted: "checkmark.circle"
    }
  }

  var accessibilityIdentifier: String {
    "popover.header.\(rawValue.lowercased())"
  }
}

struct PopoverToastView: View {
  let toast: Toast

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: iconName)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(accentColor)
      Text(toast.message)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.primary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(accentColor.opacity(0.12))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(accentColor.opacity(0.25), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.top, 48)
    .transition(.move(edge: .top).combined(with: .opacity))
  }

  private var iconName: String {
    switch toast.style {
    case .success: "checkmark.circle.fill"
    case .error: "xmark.circle.fill"
    }
  }

  private var accentColor: Color {
    switch toast.style {
    case .success: AppColors.success
    case .error: Color(red: 0.94, green: 0.27, blue: 0.27)
    }
  }
}

struct PopoverHeaderView: View {
  nonisolated static let minimumControlHitSize: CGFloat = 28
  nonisolated static let settingsButtonTitle = "Settings"
  nonisolated static let preferencesAccessibilityLabel = "Open preferences"
  nonisolated static let newCaptureAccessibilityLabel = "New capture"
  nonisolated static let settingsButtonAccessibilityIdentifier = "popover.header.settings"
  nonisolated static let newCaptureAccessibilityIdentifier = "popover.header.newCapture"
  nonisolated static let workspaceTitles = PopoverWorkspace.allCases.map(\.rawValue)
  nonisolated static let queueToggleAccessibilityIdentifier = "popover.header.queue"
  nonisolated static let postedToggleAccessibilityIdentifier = "popover.header.posted"
  nonisolated static let plannerToggleAccessibilityIdentifier = "popover.header.planner"
  nonisolated static let channelsToggleAccessibilityIdentifier = "popover.header.channels"
  nonisolated static let projectsToggleAccessibilityIdentifier = "popover.header.projects"

  @Binding var selectedWorkspace: PopoverWorkspace
  let onOpenPreferences: () -> Void
  let onNewCapture: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Text("RedditReminder")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
        Spacer()
        Button(action: onOpenPreferences) {
          Label(Self.settingsButtonTitle, systemImage: "gearshape")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(minHeight: Self.minimumControlHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Self.preferencesAccessibilityLabel)
        .accessibilityLabel(Self.preferencesAccessibilityLabel)
        .accessibilityIdentifier(Self.settingsButtonAccessibilityIdentifier)
        Button(action: onNewCapture) {
          Image(systemName: "plus").font(.system(size: 14, weight: .light))
            .foregroundStyle(AppColors.redditOrange)
            .frame(
              width: Self.minimumControlHitSize,
              height: Self.minimumControlHitSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Self.newCaptureAccessibilityLabel)
        .accessibilityLabel(Self.newCaptureAccessibilityLabel)
        .accessibilityIdentifier(Self.newCaptureAccessibilityIdentifier)
        .padding(.leading, 8)
      }

      HStack(spacing: 4) {
        ForEach(PopoverWorkspace.allCases, id: \.self) { workspace in
          toggleButton(workspace)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 10)
    .overlay(alignment: .bottom) { Divider() }
  }

  private func toggleButton(_ workspace: PopoverWorkspace) -> some View {
    let active = selectedWorkspace == workspace
    return Button(action: { selectedWorkspace = workspace }) {
      Label(workspace.rawValue, systemImage: workspace.iconName)
        .font(.system(size: 10, weight: active ? .semibold : .medium))
        .foregroundStyle(active ? AppColors.redditOrange : .secondary)
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity, minHeight: Self.minimumControlHitSize)
        .padding(.vertical, 5)
        .background(active ? AppColors.redditOrange.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    .buttonStyle(.plain)
    .help(workspace.rawValue)
    .accessibilityLabel(workspace.rawValue)
    .accessibilityIdentifier(workspace.accessibilityIdentifier)
  }
}

struct PopoverSearchBarView: View {
  nonisolated static let clearSearchAccessibilityLabel = "Clear search"
  nonisolated static let clearSearchAccessibilityIdentifier = "popover.search.clear"
  nonisolated static let clearSearchHitSize: CGFloat = 28

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
            .frame(width: Self.clearSearchHitSize, height: Self.clearSearchHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Self.clearSearchAccessibilityLabel)
        .accessibilityLabel(Self.clearSearchAccessibilityLabel)
        .accessibilityIdentifier(Self.clearSearchAccessibilityIdentifier)
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
