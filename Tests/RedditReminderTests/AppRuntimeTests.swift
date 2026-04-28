import Testing
@testable import RedditReminder

@Test func appRuntimeDetectsXCTestConfigurationEnvironment() {
    #expect(AppRuntime.isRunningUnitTests(environment: [
        "XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"
    ]))
}

@Test func appRuntimeDetectsXCTestBundleEnvironment() {
    #expect(AppRuntime.isRunningUnitTests(environment: [
        "XCTestBundlePath": "/tmp/RedditReminderTests.xctest"
    ]))
}

@Test func appRuntimeAllowsShortcutRegistrationOutsideTests() {
    #expect(AppRuntime.shouldRegisterGlobalShortcut(environment: [:]))
}

@Test func appRuntimeSkipsShortcutRegistrationDuringTests() {
    #expect(!AppRuntime.shouldRegisterGlobalShortcut(environment: [
        "XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"
    ]))
}
