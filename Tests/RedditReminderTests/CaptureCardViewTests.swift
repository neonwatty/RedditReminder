import Testing

@testable import RedditReminder

@Test func captureCardExposesPostingActionAccessibilityLabels() {
  #expect(CaptureCardView.copyTextAccessibilityLabel == "Copy post text")
  #expect(CaptureCardView.openHandoffAccessibilityLabel == "Prepare post handoff")
  #expect(CaptureCardView.openSubmitAccessibilityLabel == "Open Reddit submit page")
  #expect(CaptureCardView.markPostedAccessibilityLabel == "Mark as posted")
}
