import Foundation

enum AppRuntime {
    static func isRunningUnitTests(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCTestBundlePath"] != nil
    }

    static func shouldRegisterGlobalShortcut(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !isRunningUnitTests(environment: environment)
    }
}
