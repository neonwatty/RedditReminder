import Foundation

struct AppVersionInfo: Equatable {
  static let defaultAppName = "RedditReminder"

  let appName: String
  let version: String
  let build: String

  static var current: AppVersionInfo {
    AppVersionInfo(bundle: .main)
  }

  init(bundle: Bundle) {
    self.init(infoDictionary: bundle.infoDictionary ?? [:])
  }

  init(infoDictionary: [String: Any]) {
    appName = Self.firstString(
      for: ["CFBundleDisplayName", "CFBundleName"],
      in: infoDictionary
    ) ?? Self.defaultAppName
    version = Self.string(for: "CFBundleShortVersionString", in: infoDictionary) ?? "Unknown"
    build = Self.string(for: "CFBundleVersion", in: infoDictionary) ?? "Unknown"
  }

  var displayText: String {
    "\(appName) \(version) (\(build))"
  }

  private static func firstString(
    for keys: [String],
    in infoDictionary: [String: Any]
  ) -> String? {
    keys.lazy.compactMap { string(for: $0, in: infoDictionary) }.first
  }

  private static func string(for key: String, in infoDictionary: [String: Any]) -> String? {
    guard let value = infoDictionary[key] as? String else { return nil }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
