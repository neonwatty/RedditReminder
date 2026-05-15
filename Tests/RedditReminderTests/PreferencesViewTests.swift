import Testing

@testable import RedditReminder

@Test func preferencesExposeBackupAsTopLevelTab() {
  let tabs = PreferencesView.Tab.allCases.map(\.rawValue)

  #expect(tabs == ["Channels", "Planner", "Projects", "General", "Backup", "Notifications"])
}

@Test @MainActor func preferencesOpenOnChannelsByDefault() {
  #expect(PreferencesView.defaultTab == .channels)
}

@Test @MainActor func channelsSetupCopyPrioritizesAddingAChannel() {
  #expect(ChannelsTabView.setupTitleText == "Add a posting channel")
  #expect(
    ChannelsTabView.firstRunSetupText
      == "Start with a subreddit so captures have a destination and reminders can use posting windows.")
  #expect(ChannelsTabView.addSubredditPlaceholder == "Subreddit name")
  #expect(ChannelsTabView.addSubredditButtonText == "Add channel")
}

@Test @MainActor func channelsKeepAdvancedTimingCollapsedAfterAdd() {
  #expect(ChannelsTabView.expandsNewSubredditAfterAdd == false)
}

@Test @MainActor func onboardingPrimaryActionIsChannelSetupBeforeCapture() {
  #expect(OnboardingEmptyView.primaryButtonText == "Add Subreddit")
  #expect(OnboardingEmptyView.secondaryButtonText == "New Capture")
  #expect(OnboardingEmptyView.setupSteps == [
    "Add subreddit/channel",
    "Create capture",
    "Enable reminders/notifications",
  ])
}

@Test @MainActor func onboardingCopyExplainsFirstRunSetupOrder() {
  #expect(OnboardingEmptyView.titleText == "Set up your posting channels")
  #expect(
    OnboardingEmptyView.descriptionText
      == "Add a subreddit first so captures have a destination and reminders can use peak posting times.")
}

@Test @MainActor func captureWindowExposesSaveGuidanceIdentifier() {
  #expect(CaptureWindowView.saveRequirementsAccessibilityIdentifier == "captureWindow.saveRequirements")
}
