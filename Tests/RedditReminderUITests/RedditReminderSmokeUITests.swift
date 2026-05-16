import XCTest

@MainActor
final class RedditReminderSmokeUITests: XCTestCase {
    func testKeyboardCommandsOpenPopoverScreens() throws {
        continueAfterFailure = false
        let app = makeSeededRedditReminderApp()
        defer { app.terminate() }

        launchAndWaitForRedditReminder(app)
        openNewCaptureRoute(in: app)
        cancelCaptureRoute(in: app)

        let settingsButton = app.buttons["popover.header.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.click()
        XCTAssertTrue(app.buttons["preferences.tab.General"].waitForExistence(timeout: 3))
    }
}
