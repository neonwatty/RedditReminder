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

  func testPreferencesTabNavigation() throws {
    continueAfterFailure = false
    let app = makeSeededRedditReminderApp()
    defer { app.terminate() }

    launchAndWaitForRedditReminder(app)
    openPreferencesRoute(in: app)

    let tabs = ["General", "Notifications", "Backup"]
    for tab in tabs {
      let tabButton = app.buttons["preferences.tab.\(tab)"]
      XCTAssertTrue(tabButton.waitForExistence(timeout: 3), "Tab '\(tab)' should exist")
      tabButton.click()
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
