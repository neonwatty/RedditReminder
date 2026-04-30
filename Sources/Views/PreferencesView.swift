import SwiftUI

struct PreferencesView: View {
  let notificationService: NotificationService
  let heuristicsStore: HeuristicsStore
  var onAppStateChanged: AppRefreshAction = {}

  @State private var selectedTab: Tab = .channels

  enum Tab: String, CaseIterable {
    case channels = "Channels"
    case planner = "Planner"
    case projects = "Projects"
    case general = "General"
    case backup = "Backup"
    case notifications = "Notifications"
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

      switch selectedTab {
      case .channels:
        ChannelsTabView(notificationService: notificationService, heuristicsStore: heuristicsStore)
      case .planner:
        PlannerTabView()
      case .projects:
        ProjectsTabView()
      case .general:
        GeneralTabView(onAppStateChanged: onAppStateChanged)
      case .backup:
        BackupTabView(onAppStateChanged: onAppStateChanged)
      case .notifications:
        NotificationsTabView(
          notificationService: notificationService,
          onAppStateChanged: onAppStateChanged
        )
      }
    }
    .frame(width: 500, height: 440)
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
  }
}
