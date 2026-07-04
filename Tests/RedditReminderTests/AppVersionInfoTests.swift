import Testing

@testable import RedditReminder

@Test func appVersionInfoFormatsDisplayNameVersionAndBuild() {
  let info = AppVersionInfo(infoDictionary: [
    "CFBundleDisplayName": "RedditReminder Dev",
    "CFBundleShortVersionString": "0.1.1",
    "CFBundleVersion": "12",
  ])

  #expect(info.appName == "RedditReminder Dev")
  #expect(info.version == "0.1.1")
  #expect(info.build == "12")
  #expect(info.displayText == "RedditReminder Dev 0.1.1 (12)")
}

@Test func appVersionInfoFallsBackToBundleName() {
  let info = AppVersionInfo(infoDictionary: [
    "CFBundleName": "RedditReminder",
    "CFBundleShortVersionString": "0.2.0",
    "CFBundleVersion": "20",
  ])

  #expect(info.appName == "RedditReminder")
  #expect(info.displayText == "RedditReminder 0.2.0 (20)")
}

@Test func appVersionInfoUsesStableFallbacksForMissingValues() {
  let info = AppVersionInfo(infoDictionary: [:])

  #expect(info.appName == AppVersionInfo.defaultAppName)
  #expect(info.version == "Unknown")
  #expect(info.build == "Unknown")
  #expect(info.displayText == "RedditReminder Unknown (Unknown)")
}

@Test func appVersionInfoIgnoresBlankBundleStrings() {
  let info = AppVersionInfo(infoDictionary: [
    "CFBundleDisplayName": " ",
    "CFBundleName": "RedditReminder",
    "CFBundleShortVersionString": "\n",
    "CFBundleVersion": " 7 ",
  ])

  #expect(info.appName == "RedditReminder")
  #expect(info.version == "Unknown")
  #expect(info.build == "7")
  #expect(info.displayText == "RedditReminder Unknown (7)")
}
