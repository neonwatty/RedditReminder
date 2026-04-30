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

    func testKeyboardCommandsOpenPrimaryWindows() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.windows["New Capture"].waitForExistence(timeout: 3))

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.windows["RedditReminder Preferences"].waitForExistence(timeout: 3))
    }
}
