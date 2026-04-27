import Testing
import Foundation
@testable import RedditReminder

@Suite(.serialized)
@MainActor
struct MenuBarControllerTests {
    @Test func initialBadgeCountIsZero() {
        let controller = MenuBarController()
        #expect(controller.badgeCount == 0)
    }

    @Test func settingBadgeCountUpdatesProperty() {
        let controller = MenuBarController()
        controller.badgeCount = 5
        #expect(controller.badgeCount == 5)
    }

    @Test func isUrgentDefaultsToFalse() {
        let controller = MenuBarController()
        #expect(controller.isUrgent == false)
    }

    @Test func settingIsUrgentUpdatesProperty() {
        let controller = MenuBarController()
        controller.isUrgent = true
        #expect(controller.isUrgent == true)
    }

    @Test func popoverIsNotVisibleByDefault() {
        let controller = MenuBarController()
        #expect(controller.isPopoverVisible == false)
    }

    @Test func settingIsPopoverVisibleUpdatesProperty() {
        let controller = MenuBarController()
        controller.isPopoverVisible = true
        #expect(controller.isPopoverVisible == true)
    }
}
