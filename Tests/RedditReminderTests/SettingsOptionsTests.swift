import Testing
@testable import RedditReminder

@Test func leadTimeOptionsAreSharedAndIncludeFifteenMinutes() {
    #expect(SettingsOptions.leadTimeMinutes == [15, 30, 60, 120])
}
