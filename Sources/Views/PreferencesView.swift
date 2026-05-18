import SwiftUI

struct PreferencesView: View {
  let notificationService: NotificationService
  let heuristicsStore: HeuristicsStore
  let initialTab: Tab
  var onAppStateChanged: AppRefreshAction = {}

  static let defaultTab: Tab = .general

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
      HStack {
        Picker("Settings section", selection: $selectedTab) {
          ForEach(Tab.allCases, id: \.self) { tab in
            Text(tab.rawValue)
              .tag(tab)
              .accessibilityLabel("\(tab.rawValue) tab")
              .accessibilityIdentifier("preferences.tab.\(tab.rawValue)")
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 320)
        .accessibilityIdentifier("preferences.tabs")
        Spacer()
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 16)
      .background(.quaternary.opacity(0.15))

      Divider()

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
