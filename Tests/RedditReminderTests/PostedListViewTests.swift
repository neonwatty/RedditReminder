import Testing

@testable import RedditReminder

@Test func postedListIconActionsDefineAccessibleHitTargetAndLabels() {
  #expect(PostedListView.minimumActionHitSize == 28)
  #expect(PostedListView.openPostedLinkAccessibilityLabel == "Open posted link")
  #expect(PostedListView.restoreAccessibilityLabel == "Move posted capture back to queue")
  #expect(PostedListView.deleteAccessibilityLabel == "Delete posted capture")
}
