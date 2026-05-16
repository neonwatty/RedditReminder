import Testing

@testable import RedditReminder

@Test func postHandoffIconButtonsDefineAccessibleHitTargetAndLabels() {
  #expect(PostHandoffView.iconButtonMinimumHitSize == 28)
  #expect(PostHandoffView.copyTitleAccessibilityLabel == "Copy post title")
  #expect(PostHandoffView.copyBodyAccessibilityLabel == "Copy post body")
  #expect(PostHandoffView.copyLinksAccessibilityLabel == "Copy post links")
  #expect(PostHandoffView.copyAllAccessibilityLabel == "Copy full post text")
}
