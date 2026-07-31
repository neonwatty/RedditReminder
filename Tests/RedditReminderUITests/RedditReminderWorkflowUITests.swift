import XCTest

@MainActor
final class RedditReminderWorkflowUITests: XCTestCase {
  func testCreateCapturePopoverAppears() throws {
    continueAfterFailure = false
    let app = makeSeededRedditReminderApp()
    defer { app.terminate() }

    launchAndWaitForRedditReminder(app)
    openNewCaptureRoute(in: app)

    let saveButton = app.buttons["captureWindow.save"]
    XCTAssertTrue(saveButton.exists)

    let cancelButton = app.buttons["captureWindow.cancel"]
    XCTAssertTrue(cancelButton.exists)
  }

  func testCaptureTextModeUsesSegmentedPreviewControl() throws {
    continueAfterFailure = false
    let app = makeSeededRedditReminderApp()
    defer { app.terminate() }

    launchAndWaitForRedditReminder(app)
    openNewCaptureRoute(in: app)

    let textEditor = app.textViews["captureWindow.text"]
    XCTAssertTrue(textEditor.waitForExistence(timeout: 3), "Capture text editor should exist")

    let modeControl = app.descendants(matching: .any)["captureWindow.text.mode"]
    XCTAssertTrue(modeControl.waitForExistence(timeout: 3), "Capture text mode control should exist")

    modeControl.coordinate(withNormalizedOffset: CGVector(dx: 0.84, dy: 0.5)).click()
    XCTAssertTrue(
      app.descendants(matching: .any)["captureWindow.text.previewContent"].waitForExistence(timeout: 3),
      "Preview content should appear after selecting Preview"
    )

    modeControl.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.5)).click()
    XCTAssertTrue(textEditor.waitForExistence(timeout: 3), "Text editor should return after selecting Edit")
  }

  func testPreferencesTabNavigation() throws {
    continueAfterFailure = false
    let app = makeSeededRedditReminderApp()
    defer { app.terminate() }

    launchAndWaitForRedditReminder(app)
    openPreferencesRoute(in: app)

    let tabs = [
      ("General", CGVector(dx: 0.16, dy: 0.5)),
      ("Notifications", CGVector(dx: 0.5, dy: 0.5)),
      ("Backup", CGVector(dx: 0.84, dy: 0.5)),
    ]
    let segmentedTabs = app.descendants(matching: .any)["preferences.tabs"]
    XCTAssertTrue(segmentedTabs.waitForExistence(timeout: 3), "Settings tabs should exist")
    for (tab, offset) in tabs {
      segmentedTabs.coordinate(withNormalizedOffset: offset).click()
      XCTAssertTrue(
        app.descendants(matching: .any)["preferences.content.\(tab)"].waitForExistence(timeout: 3),
        "Tab '\(tab)' should expose its content"
      )
    }
  }

  func testDeleteConfirmationAppears() throws {
    continueAfterFailure = false
    let app = makeSeededRedditReminderApp()
    defer { app.terminate() }

    launchAndWaitForRedditReminder(app)
    openHomePopover(in: app)
    openWorkspace("popover.header.posted", in: app)

    let deleteButton = app.buttons.matching(identifier: "postedList.delete").firstMatch
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Posted delete button should exist")
    deleteButton.click()

    let confirmationDelete = app.buttons["Delete"].firstMatch
    XCTAssertTrue(
      confirmationDelete.waitForExistence(timeout: 3),
      "Delete confirmation should expose a destructive confirmation button"
    )

    let cancelButton = app.buttons["Cancel"].firstMatch
    XCTAssertTrue(
      cancelButton.waitForExistence(timeout: 3), "Delete confirmation should be cancellable")
    cancelButton.click()
  }
}
