import SwiftUI

struct PreferencesView: View {
  let notificationService: NotificationService
  let heuristicsStore: HeuristicsStore
  let initialTab: Tab
  var onAppStateChanged: AppRefreshAction = {}

  static let defaultTab: Tab = .general
  static let versionFooterAccessibilityIdentifier = "preferences.footer.version"

  @State private var selectedTab: Tab

  enum Tab: String, CaseIterable {
    case general = "General"
    case notifications = "Notifications"
    case backup = "Backup"
  }

  init(
    notificationService: NotificationService,
    heuristicsStore: HeuristicsStore,
    initialTab: Tab = Self.defaultTab,
    onAppStateChanged: @escaping AppRefreshAction = {}
  ) {
    self.notificationService = notificationService
    self.heuristicsStore = heuristicsStore
    self.initialTab = initialTab
    self.onAppStateChanged = onAppStateChanged
    _selectedTab = State(initialValue: initialTab)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(Tab.allCases, id: \.self) { tab in
          Button(action: { selectedTab = tab }) {
            Text(tab.rawValue)
              .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
              .foregroundStyle(selectedTab == tab ? AppColors.redditOrange : .secondary)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(
                selectedTab == tab
                  ? AppColors.redditOrange.opacity(0.1)
                  : Color.clear
              )
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(tab.rawValue) tab")
          .accessibilityIdentifier("preferences.tab.\(tab.rawValue)")
        }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 16)
      .background(.quaternary.opacity(0.15))

      Divider()

      Group {
        switch selectedTab {
        case .general:
          GeneralTabView(onAppStateChanged: onAppStateChanged)
        case .notifications:
          NotificationsTabView(
            notificationService: notificationService,
            onAppStateChanged: onAppStateChanged
          )
        case .backup:
          BackupTabView(onAppStateChanged: onAppStateChanged)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      Text(AppVersionInfo.current.displayText)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(Self.versionFooterAccessibilityIdentifier)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct BackupTabView: View {
  var onAppStateChanged: AppRefreshAction = {}

  var body: some View {
    Form {
      Section("Backup") {
        BackupSectionView(onAppStateChanged: onAppStateChanged)
      }
    }
    .formStyle(.grouped)
    .padding(8)
    .accessibilityIdentifier("preferences.content.Backup")
  }
}
