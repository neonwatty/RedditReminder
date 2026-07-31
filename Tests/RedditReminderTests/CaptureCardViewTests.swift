import Testing

@testable import RedditReminder

@Test func captureCardExposesPostingActionAccessibilityLabels() {
  #expect(CaptureCardView.copyTextAccessibilityLabel == "Copy post text")
  #expect(CaptureCardView.openHandoffAccessibilityLabel == "Prepare post handoff")
  #expect(CaptureCardView.visiblePrimaryActionAccessibilityLabel == "Prepare post handoff")
  #expect(CaptureCardView.openSubmitAccessibilityLabel == "Open Reddit submit page")
  #expect(CaptureCardView.markPostedAccessibilityLabel == "Mark as posted")
  #expect(CaptureCardView.deleteAccessibilityLabel == "Delete capture")
  #expect(CaptureCardView.moreActionsAccessibilityLabel == "More capture actions")
}

@Test func captureCardVisiblePrimaryActionUsesHandoff() {
  #expect(CaptureCardView.visiblePrimaryActionAccessibilityLabel == CaptureCardView.openHandoffAccessibilityLabel)
}

@Test func postedListExposesVisibleRecoveryActionAccessibilityLabels() {
  #expect(PostedListView.openPostedLinkAccessibilityLabel == "Open posted link")
  #expect(PostedListView.restoreAccessibilityLabel == "Move posted capture back to queue")
  #expect(PostedListView.deleteAccessibilityLabel == "Delete posted capture")
}

@Test func managementRowsExposeVisibleActionMenuLabels() {
  #expect(ProjectsTabView.moreActionsAccessibilityLabel == "More project actions")
  #expect(ProjectsTabView.renameAccessibilityLabel == "Rename project")
  #expect(ProjectsTabView.archiveAccessibilityLabel == "Archive project")
  #expect(ProjectsTabView.unarchiveAccessibilityLabel == "Unarchive project")
  #expect(ProjectsTabView.deleteAccessibilityLabel == "Delete project")
  #expect(SubredditRow.moreActionsAccessibilityLabel == "More channel actions")
  #expect(SubredditRow.editWindowsAccessibilityLabel == "Edit channel windows")
  #expect(SubredditRow.moveUpAccessibilityLabel == "Move channel up")
  #expect(SubredditRow.moveDownAccessibilityLabel == "Move channel down")
  #expect(SubredditRow.removeAccessibilityLabel == "Remove channel")
  #expect(SubredditRow.collapsedRowsUseCardChrome == false)
  #expect(SubredditRow.expandedRowsUseCardChrome == true)
}
