import Foundation

enum AppRuntime {
  static let uiTestStoreLaunchArgument = "--ui-test-store"

  static func isRunningUnitTests(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Bool {
    environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
  }

  static func shouldRegisterGlobalShortcut(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Bool {
    !isRunningUnitTests(environment: environment)
  }

  static func uiTestStoreURL(arguments: [String] = ProcessInfo.processInfo.arguments) -> URL? {
    for (index, argument) in arguments.enumerated() {
      if argument == uiTestStoreLaunchArgument {
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return URL(fileURLWithPath: arguments[valueIndex])
      }

      let prefix = "\(uiTestStoreLaunchArgument)="
      if argument.hasPrefix(prefix) {
        let path = String(argument.dropFirst(prefix.count))
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
      }
    }

    return nil
  }
}
