import Testing

@testable import RedditReminder

@Test func preferencesExposeBackupAsTopLevelTab() {
  let tabs = PreferencesView.Tab.allCases.map(\.rawValue)

  #expect(tabs == ["Channels", "Planner", "Projects", "General", "Backup", "Notifications"])
}
