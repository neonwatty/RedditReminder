import XCTest

final class RedditReminderSmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--seed-qa"]
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testKeyboardCommandsOpenPopoverScreens() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.textFields["captureWindow.title"].waitForExistence(timeout: 3))

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["preferences.tab.Channels"].waitForExistence(timeout: 3))
    }
}
