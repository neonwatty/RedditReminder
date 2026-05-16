import Foundation
import Testing

@testable import RedditReminder

@Test func appRuntimeDetectsXCTestConfigurationEnvironment() {
  #expect(
    AppRuntime.isRunningUnitTests(environment: [
      "XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"
    ]))
}

@Test func appRuntimeDetectsXCTestBundleEnvironment() {
  #expect(
    AppRuntime.isRunningUnitTests(environment: [
      "XCTestBundlePath": "/tmp/RedditReminderTests.xctest"
    ]))
}

@Test func appRuntimeAllowsShortcutRegistrationOutsideTests() {
  #expect(AppRuntime.shouldRegisterGlobalShortcut(environment: [:]))
}

@Test func appRuntimeSkipsShortcutRegistrationDuringTests() {
  #expect(
    !AppRuntime.shouldRegisterGlobalShortcut(environment: [
      "XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"
    ]))
}

@Test func appRuntimeParsesUITestStoreArgumentPair() {
  let url = AppRuntime.uiTestStoreURL(arguments: [
    "RedditReminder",
    "--ui-test-store",
    "/tmp/redditreminder-ui-tests.store",
  ])

  #expect(url == URL(fileURLWithPath: "/tmp/redditreminder-ui-tests.store"))
}

@Test func appRuntimeParsesUITestStoreArgumentAssignment() {
  let url = AppRuntime.uiTestStoreURL(arguments: [
    "RedditReminder",
    "--ui-test-store=/tmp/redditreminder-ui-tests.store",
  ])

  #expect(url == URL(fileURLWithPath: "/tmp/redditreminder-ui-tests.store"))
}

@Test func appRuntimeIgnoresMissingUITestStoreValue() {
  #expect(AppRuntime.uiTestStoreURL(arguments: ["RedditReminder", "--ui-test-store"]) == nil)
  #expect(AppRuntime.uiTestStoreURL(arguments: ["RedditReminder"]) == nil)
}
