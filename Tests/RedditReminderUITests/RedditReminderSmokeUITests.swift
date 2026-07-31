import XCTest

@MainActor
final class RedditReminderSmokeUITests: XCTestCase {
    func testPopoverChromePrimaryControlsRemainVisible() throws {
        continueAfterFailure = false
        let app = makeSeededRedditReminderApp()
        defer { app.terminate() }

        launchAndWaitForRedditReminder(app)
        openHomePopover(in: app)

        let controlIdentifiers = [
            "popover.header.queue",
            "popover.header.posted",
            "popover.header.planner",
            "popover.header.channels",
            "popover.header.projects",
            "popover.header.settings",
            "popover.header.newCapture",
        ]

        for identifier in controlIdentifiers {
            let control = app.buttons[identifier]
            XCTAssertTrue(control.waitForExistence(timeout: 3), "\(identifier) should exist")
            XCTAssertGreaterThan(control.frame.width, 10, "\(identifier) should have visible width")
            XCTAssertGreaterThan(control.frame.height, 10, "\(identifier) should have visible height")
        }
    }

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
    XCTAssertTrue(app.descendants(matching: .any)["preferences.content.General"].waitForExistence(timeout: 3))
  }
}
