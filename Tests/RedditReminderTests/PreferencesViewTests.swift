import Foundation
import Testing

@testable import RedditReminder

@Test func preferencesExposeBackupAsTopLevelTab() {
  let tabs = PreferencesView.Tab.allCases.map(\.rawValue)

  #expect(tabs == ["General", "Notifications", "Backup"])
}

@Test @MainActor func preferencesOpenOnGeneralByDefault() {
  #expect(PreferencesView.defaultTab == .general)
}

@Test @MainActor func channelsSetupCopyPrioritizesAddingAChannel() {
  #expect(ChannelsTabView.setupTitleText == "Add a posting channel")
  #expect(
    ChannelsTabView.firstRunSetupText
      == "Start with a subreddit so captures have a destination and reminders can use posting windows.")
  #expect(
    ChannelsTabView.firstChannelAddedText
      == "Posting windows were generated for this channel. Create your first capture when you are ready.")
  #expect(ChannelsTabView.createFirstCaptureButtonText == "Create first capture")
  #expect(ChannelsTabView.addSubredditPlaceholder == "Subreddit name")
  #expect(ChannelsTabView.addSubredditButtonText == "Add channel")
}

@Test @MainActor func channelsKeepAdvancedTimingCollapsedAfterAdd() {
  #expect(ChannelsTabView.expandsNewSubredditAfterAdd == false)
}

@Test @MainActor func onboardingPrimaryActionIsChannelSetupBeforeCapture() {
  #expect(OnboardingEmptyView.primaryButtonText == "Add Channel")
  #expect(OnboardingEmptyView.secondaryButtonText == "New Capture")
  #expect(OnboardingEmptyView.notificationsButtonText == "Enable Reminders")
  #expect(OnboardingEmptyView.setupSteps == [
    "Add a subreddit channel",
    "Create your first capture",
    "Enable reminder notifications",
  ])
}

@Test @MainActor func onboardingCopyExplainsFirstRunSetupOrder() {
  #expect(OnboardingEmptyView.titleText == "Set up your posting channels")
  #expect(
    OnboardingEmptyView.descriptionText
      == "Add a subreddit first, then create a capture and turn on reminders for posting windows.")
}

@Test @MainActor func captureWindowExposesSaveGuidanceIdentifier() {
  #expect(CaptureWindowView.saveRequirementsAccessibilityIdentifier == "captureWindow.saveRequirements")
}

@Test @MainActor func captureSubredditPickerExplainsNoChannelRecovery() {
  #expect(CaptureSubredditPicker.emptyTitleText == "No channels yet")
  #expect(
    CaptureSubredditPicker.emptyDescriptionText
      == "Add a subreddit channel before saving this capture.")
  #expect(CaptureSubredditPicker.addChannelButtonText == "Add channel")
  #expect(
    CaptureSubredditPicker.addChannelButtonAccessibilityIdentifier == "captureWindow.addChannel")
}

@Test func captureFormDraftPreservesCreateInputsForChannelRecovery() {
  let projectId = UUID()
  let subredditId = UUID()
  let mediaURL = URL(fileURLWithPath: "/tmp/redditreminder-draft.png")

  let draft = CaptureFormDraft(
    title: "Launch notes",
    text: "Body",
    notes: "Private reminder",
    selectedProjectId: projectId,
    selectedSubredditIds: [subredditId],
    links: ["https://example.com"],
    newLinkText: "example.org",
    mediaURLs: [mediaURL]
  )

  #expect(draft.title == "Launch notes")
  #expect(draft.text == "Body")
  #expect(draft.notes == "Private reminder")
  #expect(draft.selectedProjectId == projectId)
  #expect(draft.selectedSubredditIds == [subredditId])
  #expect(draft.links == ["https://example.com"])
  #expect(draft.newLinkText == "example.org")
  #expect(draft.mediaURLs == [mediaURL])
  #expect(draft.hasRecoverableContent)
}

@Test func captureFormDraftTreatsPendingLinkAndMediaAsRecoverableContent() {
  #expect(CaptureFormDraft().hasRecoverableContent == false)
  #expect(CaptureFormDraft(newLinkText: "reddit.com/r/macOS").hasRecoverableContent)
  #expect(
    CaptureFormDraft(mediaURLs: [URL(fileURLWithPath: "/tmp/redditreminder-draft.mov")])
      .hasRecoverableContent)
}
