import Testing

@testable import RedditReminder

@Test func captureCardExposesPostingActionAccessibilityLabels() {
  #expect(CaptureCardView.copyTextAccessibilityLabel == "Copy post text")
  #expect(CaptureCardView.openHandoffAccessibilityLabel == "Prepare post handoff")
  #expect(CaptureCardView.openSubmitAccessibilityLabel == "Open Reddit submit page")
  #expect(CaptureCardView.markPostedAccessibilityLabel == "Mark as posted")
  #expect(CaptureCardView.deleteAccessibilityLabel == "Delete capture")
}

@Test func postedListExposesVisibleRecoveryActionAccessibilityLabels() {
  #expect(PostedListView.openPostedLinkAccessibilityLabel == "Open posted link")
  #expect(PostedListView.restoreAccessibilityLabel == "Move posted capture back to queue")
  #expect(PostedListView.deleteAccessibilityLabel == "Delete posted capture")
}
