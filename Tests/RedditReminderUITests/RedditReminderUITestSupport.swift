import XCTest

@MainActor
extension XCTestCase {
    func makeSeededRedditReminderApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--seed-qa"]
        return app
    }

    func makeClearedRedditReminderApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--clear-qa"]
        return app
    }

    func launchAndWaitForRedditReminder(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5),
            "RedditReminder should launch for UI testing"
        )
        app.activate()
    }

    func openNewCaptureRoute(in app: XCUIApplication) {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(
            app.textFields["captureWindow.title"].waitForExistence(timeout: 3),
            "New Capture route should expose the title field"
        )
    }

    func cancelCaptureRoute(in app: XCUIApplication) {
        let cancel = app.buttons["captureWindow.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Cancel button should exist")
        cancel.click()
    }

    func openPreferencesRoute(in app: XCUIApplication) {
        openHomePopover(in: app)
        let settingsButton = app.buttons["popover.header.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Settings button should exist")
        settingsButton.click()
        XCTAssertTrue(
            app.buttons["preferences.tab.General"].waitForExistence(timeout: 3),
            "Preferences route should expose the General tab"
        )
    }

    func openHomePopover(in app: XCUIApplication) {
        openNewCaptureRoute(in: app)
        cancelCaptureRoute(in: app)
    }

    func openWorkspace(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Workspace button \(identifier) should exist")
        button.click()
    }

    func firstButton(withIdentifierPrefix prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }
}
