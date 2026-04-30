import Testing

@testable import RedditReminder

@Test func popoverHeaderExposesVisibleSettingsEntry() {
  #expect(PopoverHeaderView.settingsButtonTitle == "Settings")
  #expect(PopoverHeaderView.preferencesAccessibilityLabel == "Open preferences")
  #expect(PopoverHeaderView.queueToggleAccessibilityIdentifier == "popover.header.queue")
  #expect(PopoverHeaderView.postedToggleAccessibilityIdentifier == "popover.header.posted")
}
