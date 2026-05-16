import XCTest

@MainActor
final class RedditReminderUXFlowUITests: XCTestCase {
    func testInvalidLinkShowsInlineValidationAndPreservesInput() throws {
        continueAfterFailure = false
        let app = makeSeededRedditReminderApp()
        defer { app.terminate() }

        launchAndWaitForRedditReminder(app)
        openNewCaptureRoute(in: app)

        let linkField = app.textFields["captureWindow.links.newLink"]
        XCTAssertTrue(linkField.waitForExistence(timeout: 3))
        linkField.click()
        linkField.typeText("bad domain.com")

        let addButton = app.buttons["captureWindow.links.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.click()

        XCTAssertTrue(app.staticTexts["captureWindow.links.validation"].waitForExistence(timeout: 2))
        XCTAssertEqual(linkField.value as? String, "bad domain.com")
    }

    func testPostedActionsAreReachableFromSeededData() throws {
        continueAfterFailure = false
        let app = makeSeededRedditReminderApp()
        defer { app.terminate() }

        launchAndWaitForRedditReminder(app)
        openHomePopover(in: app)
        openWorkspace("popover.header.posted", in: app)

        XCTAssertTrue(app.buttons["postedList.openPostedLink"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["postedList.restore"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["postedList.delete"].waitForExistence(timeout: 3))
    }

    func testPlannerCreateActionOpensCaptureWithChannelContext() throws {
        continueAfterFailure = false
        let app = makeSeededRedditReminderApp()
        defer { app.terminate() }

        launchAndWaitForRedditReminder(app)
        openHomePopover(in: app)
        openWorkspace("popover.header.planner", in: app)

        let createButton = firstButton(withIdentifierPrefix: "planner.createCapture.", in: app)
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.click()

        let titleField = app.textFields["captureWindow.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.click()
        titleField.typeText("Planner context title")

        let textView = app.textViews["captureWindow.text"]
        XCTAssertTrue(textView.waitForExistence(timeout: 3))
        textView.click()
        textView.typeText("Planner context body")

        XCTAssertTrue(app.buttons["captureWindow.save"].isEnabled)
    }

    func testNoChannelAddChannelPreservesDraftFields() throws {
        continueAfterFailure = false
        let app = makeClearedRedditReminderApp()
        defer { app.terminate() }

        launchAndWaitForRedditReminder(app)
        openNewCaptureRoute(in: app)

        let titleField = app.textFields["captureWindow.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.click()
        titleField.typeText("Recovered QA title")

        let textView = app.textViews["captureWindow.text"]
        XCTAssertTrue(textView.waitForExistence(timeout: 3))
        textView.click()
        textView.typeText("Recovered body text")

        let linkField = app.textFields["captureWindow.links.newLink"]
        XCTAssertTrue(linkField.waitForExistence(timeout: 3))
        linkField.click()
        linkField.typeText("https://example.com/recovered-draft")

        let addChannel = app.buttons["captureWindow.addChannel"]
        XCTAssertTrue(addChannel.waitForExistence(timeout: 3))
        addChannel.click()

        let channelField = app.textFields["channels.addSubreddit.textField"]
        XCTAssertTrue(channelField.waitForExistence(timeout: 3))
        channelField.click()
        channelField.typeText("RecoveredQA")

        let addChannelButton = app.buttons["channels.addSubreddit.button"]
        XCTAssertTrue(addChannelButton.waitForExistence(timeout: 3))
        addChannelButton.click()

        let createFirstCapture = app.buttons["channels.createFirstCapture"]
        XCTAssertTrue(createFirstCapture.waitForExistence(timeout: 3))
        createFirstCapture.click()

        let recoveredTitleField = app.textFields["captureWindow.title"]
        XCTAssertTrue(recoveredTitleField.waitForExistence(timeout: 3))

        let saveButton = app.buttons["captureWindow.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.click()
        XCTAssertTrue(
            app.buttons["popover.header.queue"].waitForExistence(timeout: 3),
            "Recovered draft should be savable after adding the first channel"
        )
    }
}
