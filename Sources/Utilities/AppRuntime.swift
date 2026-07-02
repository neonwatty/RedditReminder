import Foundation

enum AppRuntime {
  static let uiTestStoreLaunchArgument = "--ui-test-store"
  static let productionBundleIdentifier = "com.neonwatty.RedditReminder"
  static let developmentBundleIdentifier = "com.neonwatty.RedditReminder.Dev"
  static let productionAppSupportDirectoryName = "RedditReminder"
  static let developmentAppSupportDirectoryName = "RedditReminder Dev"

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

  static func isDevelopmentFlavor(
    bundleIdentifier: String? = Bundle.main.bundleIdentifier,
    processName: String = ProcessInfo.processInfo.processName
  ) -> Bool {
    bundleIdentifier == developmentBundleIdentifier
      || processName == developmentAppSupportDirectoryName
  }

  static func appSupportDirectoryName(
    bundleIdentifier: String? = Bundle.main.bundleIdentifier,
    processName: String = ProcessInfo.processInfo.processName
  ) -> String {
    isDevelopmentFlavor(bundleIdentifier: bundleIdentifier, processName: processName)
      ? developmentAppSupportDirectoryName
      : productionAppSupportDirectoryName
  }

  static func appSupportDirectory(
    bundleIdentifier: String? = Bundle.main.bundleIdentifier,
    processName: String = ProcessInfo.processInfo.processName
  ) -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(
        appSupportDirectoryName(bundleIdentifier: bundleIdentifier, processName: processName),
        isDirectory: true)
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
