import Testing

@testable import RedditReminder

@Test func popoverHeaderExposesVisibleSettingsEntry() {
  #expect(PopoverHeaderView.minimumControlHitSize == 28)
  #expect(PopoverHeaderView.settingsButtonTitle == "Settings")
  #expect(PopoverHeaderView.preferencesAccessibilityLabel == "Open preferences")
  #expect(PopoverHeaderView.settingsButtonAccessibilityIdentifier == "popover.header.settings")
  #expect(PopoverHeaderView.newCaptureAccessibilityIdentifier == "popover.header.newCapture")
  #expect(PopoverHeaderView.workspaceTitles == ["Queue", "Planner", "Channels", "Projects", "Posted"])
  #expect(PopoverHeaderView.queueToggleAccessibilityIdentifier == "popover.header.queue")
  #expect(PopoverHeaderView.plannerToggleAccessibilityIdentifier == "popover.header.planner")
  #expect(PopoverHeaderView.channelsToggleAccessibilityIdentifier == "popover.header.channels")
  #expect(PopoverHeaderView.projectsToggleAccessibilityIdentifier == "popover.header.projects")
  #expect(PopoverHeaderView.postedToggleAccessibilityIdentifier == "popover.header.posted")
}

@Test func popoverSearchClearButtonDefinesAccessibleHitTarget() {
  #expect(PopoverSearchBarView.clearSearchAccessibilityLabel == "Clear search")
  #expect(PopoverSearchBarView.clearSearchAccessibilityIdentifier == "popover.search.clear")
  #expect(PopoverSearchBarView.clearSearchHitSize == 28)
}

@Test func popoverChromeUsesSystemMaterial() {
  #expect(AppColors.popoverUsesSystemMaterial)
}

@Test @MainActor func plannerExposesActionLabels() {
  #expect(PlannerTabView.createCaptureActionText == "Create capture")
  #expect(PlannerTabView.viewQueueActionText == "View queue")
  #expect(PlannerTabView.editChannelsActionText == "Edit windows")
  #expect(PlannerTabView.viewModeAccessibilityIdentifier == "planner.viewMode")
  #expect(PlannerTabView.rowActionHitSize == 28)
}

@Test @MainActor func queueEmptyWithWindowsExposesCreateCaptureCTA() {
  #expect(PopoverContentView.emptyQueueWithWindowsTitleText == "No captures queued")
  #expect(
    PopoverContentView.emptyQueueWithWindowsDescriptionText
      == "Create a capture so your next posting windows have a draft ready.")
  #expect(PopoverContentView.emptyQueueWithWindowsButtonText == "Create capture")
  #expect(
    PopoverContentView.emptyQueueWithWindowsButtonIdentifier
      == "queue.emptyWithWindows.createCapture")
  #expect(PopoverContentView.filteredEmptyButtonText == "New capture for this subreddit")
  #expect(
    PopoverContentView.filteredEmptyButtonIdentifier == "queue.filteredEmpty.createCapture")
}

@Test @MainActor func queuePresentationShowsOnboardingOnlyWhenNoCapturesNoWindowsAndUnfiltered() {
  #expect(
    PopoverContentView.queueContentPresentation(
      displayedCaptureCount: 0,
      upcomingWindowCount: 0,
      isFiltered: false
    ) == .onboarding)
}

@Test @MainActor func queuePresentationShowsEmptyWithWindowsOnlyWhenUnfilteredQueueIsEmptyWithWindows() {
  #expect(
    PopoverContentView.queueContentPresentation(
      displayedCaptureCount: 0,
      upcomingWindowCount: 1,
      isFiltered: false
    ) == .emptyWithWindows)
}

@Test @MainActor func queuePresentationShowsFilteredEmptyBeforeWindowCTA() {
  #expect(
    PopoverContentView.queueContentPresentation(
      displayedCaptureCount: 0,
      upcomingWindowCount: 1,
      isFiltered: true
    ) == .filteredEmpty)
}

@Test @MainActor func queuePresentationShowsListWhenCapturesAreVisible() {
  #expect(
    PopoverContentView.queueContentPresentation(
      displayedCaptureCount: 1,
      upcomingWindowCount: 0,
      isFiltered: false
    ) == .list)
  #expect(
    PopoverContentView.queueContentPresentation(
      displayedCaptureCount: 1,
      upcomingWindowCount: 1,
      isFiltered: true
    ) == .list)
}
