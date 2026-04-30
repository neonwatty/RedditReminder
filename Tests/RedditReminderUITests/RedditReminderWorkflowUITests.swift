import XCTest

final class RedditReminderWorkflowUITests: XCTestCase {
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

    func testCreateCaptureWindowAppears() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()
        app.typeKey("n", modifierFlags: .command)

        let captureWindow = app.windows["New Capture"]
        XCTAssertTrue(captureWindow.waitForExistence(timeout: 3))

        let titleField = captureWindow.textFields["captureWindow.title"]
        XCTAssertTrue(titleField.exists)

        let saveButton = captureWindow.buttons["captureWindow.save"]
        XCTAssertTrue(saveButton.exists)

        let cancelButton = captureWindow.buttons["captureWindow.cancel"]
        XCTAssertTrue(cancelButton.exists)
    }

    func testPreferencesTabNavigation() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()
        app.typeKey(",", modifierFlags: .command)

        let prefsWindow = app.windows["RedditReminder Preferences"]
        XCTAssertTrue(prefsWindow.waitForExistence(timeout: 3))

        let tabs = ["Channels", "Planner", "Projects", "General", "Backup", "Notifications"]
        for tab in tabs {
            let tabButton = prefsWindow.buttons["preferences.tab.\(tab)"]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 2), "Tab '\(tab)' should exist")
            tabButton.click()
            // Brief pause for tab content to load
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    func testDeleteConfirmationAppears() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()

        // With --seed-qa, there should be capture cards in the popover.
        // Right-click to access the context menu.
        let captureCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "capture")
        ).firstMatch
        guard captureCard.waitForExistence(timeout: 3) else {
            XCTFail("No capture cards found — QA fixtures may not have seeded")
            return
        }

        captureCard.rightClick()
        let deleteMenuItem = app.menuItems["Delete"]
        guard deleteMenuItem.waitForExistence(timeout: 2) else {
            XCTFail("Delete menu item not found in context menu")
            return
        }
        deleteMenuItem.click()

        // The NSAlert confirmation should appear
        let alert = app.dialogs.firstMatch
        XCTAssertTrue(
            alert.waitForExistence(timeout: 3),
            "Delete confirmation dialog should appear"
        )

        // Cancel to preserve the capture
        let cancelButton = alert.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        }
    }
}
