import Testing

@testable import RedditReminder

@Test func postHandoffIconButtonsDefineAccessibleHitTargetAndLabels() {
  #expect(PostHandoffView.iconButtonMinimumHitSize == 28)
  #expect(PostHandoffView.copyTitleAccessibilityLabel == "Copy post title")
  #expect(PostHandoffView.copyBodyAccessibilityLabel == "Copy post body")
  #expect(PostHandoffView.copyLinksAccessibilityLabel == "Copy post links")
  #expect(PostHandoffView.copyAllAccessibilityLabel == "Copy full post text")
  #expect(PostHandoffView.openSubmitAccessibilityLabel == "Open Reddit submit page")
  #expect(PostHandoffView.markPostedButtonText(destinationCount: 1) == "Mark Posted")
  #expect(PostHandoffView.markPostedButtonText(destinationCount: 2) == "Mark All Posted")
  #expect(PostHandoffView.markPostedAccessibilityLabel(destinationCount: 1) == "Mark posted")
  #expect(
    PostHandoffView.markPostedAccessibilityLabel(destinationCount: 2)
      == "Mark all destinations posted")
  #expect(
    PostHandoffView.chooseSubmitDestinationAccessibilityLabel == "Choose Reddit submit destination"
  )
}
