import Testing
import Foundation
@testable import RedditReminder

// MARK: - UTC midnight boundary

@Test @MainActor func peakAtUtcMidnight() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    // Override to peak at hour 0 (midnight UTC) on Monday
    store.setOverride(for: "r/Test", peakDays: ["mon"], peakHoursUtc: [0])

    let mondayMidnight = dayOfWeek(.monday, at: 0)
    #expect(store.isPeakWindow(for: "r/Test", at: mondayMidnight))
}

@Test @MainActor func peakAtUtcHour23() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    store.setOverride(for: "r/Test", peakDays: ["fri"], peakHoursUtc: [23])

    let friday23 = dayOfWeek(.friday, at: 23)
    #expect(store.isPeakWindow(for: "r/Test", at: friday23))
}

// MARK: - Day AND hour must match

@Test @MainActor func peakDayWrongHourReturnsFalse() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    store.setOverride(for: "r/Test", peakDays: ["tue"], peakHoursUtc: [14])

    let tuesdayWrongHour = dayOfWeek(.tuesday, at: 10)
    #expect(!store.isPeakWindow(for: "r/Test", at: tuesdayWrongHour))
}

@Test @MainActor func peakHourWrongDayReturnsFalse() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    store.setOverride(for: "r/Test", peakDays: ["tue"], peakHoursUtc: [14])

    let wednesdayRightHour = dayOfWeek(.wednesday, at: 14)
    #expect(!store.isPeakWindow(for: "r/Test", at: wednesdayRightHour))
}

// MARK: - All 7 weekday abbreviation mappings

@Test @MainActor func allWeekdayAbbreviationsRecognized() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    let allDays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    let allWeekdays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    store.setOverride(for: "r/AllDays", peakDays: allDays, peakHoursUtc: [12])

    for weekday in allWeekdays {
        let date = dayOfWeek(weekday, at: 12)
        #expect(store.isPeakWindow(for: "r/AllDays", at: date))
    }
}

// MARK: - Multiple peak hours

@Test @MainActor func multiplePeakHoursAllMatch() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    store.setOverride(for: "r/Test", peakDays: ["mon"], peakHoursUtc: [9, 14, 20])

    for hour in [9, 14, 20] {
        let date = dayOfWeek(.monday, at: hour)
        #expect(store.isPeakWindow(for: "r/Test", at: date))
    }
}

@Test @MainActor func nonPeakHourBetweenPeaksReturnsFalse() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    store.setOverride(for: "r/Test", peakDays: ["mon"], peakHoursUtc: [9, 14])

    let between = dayOfWeek(.monday, at: 11)
    #expect(!store.isPeakWindow(for: "r/Test", at: between))
}

// MARK: - Unknown subreddit

@Test @MainActor func unknownSubredditNeverPeak() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    let anyDate = dayOfWeek(.monday, at: 14)
    #expect(!store.isPeakWindow(for: "r/TotallyUnknown", at: anyDate))
}

// MARK: - Override completely replaces bundled

@Test @MainActor func overrideReplacesNotMerges() {
    let store = HeuristicsStore(bundle: makeTestBundle())

    // r/SideProject has bundled: peakDays ["tue", "sat"], peakHoursUtc [14]
    store.setOverride(for: "r/SideProject", peakDays: ["wed"], peakHoursUtc: [10])

    // Bundled peak should no longer match
    let tuesdayOldPeak = dayOfWeek(.tuesday, at: 14)
    #expect(!store.isPeakWindow(for: "r/SideProject", at: tuesdayOldPeak))

    // New override should match
    let wednesdayNewPeak = dayOfWeek(.wednesday, at: 10)
    #expect(store.isPeakWindow(for: "r/SideProject", at: wednesdayNewPeak))
}

// MARK: - Empty bundle fallback

@Test @MainActor func missingBundleProducesEmptyStore() throws {
    // Create a real but empty temp directory as a bundle — no peak-times.json inside
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let emptyBundle = Bundle(path: tempDir.path)!

    let store = HeuristicsStore(bundle: emptyBundle)
    let peak = store.peakInfo(for: "r/SideProject")
    #expect(peak == nil) // no bundled data loaded
}

// MARK: - Bundled data integrity

@Test @MainActor func bundledDataContainsExpectedSubreddits() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    // peak-times.json should have r/SideProject at minimum
    let peak = store.peakInfo(for: "r/SideProject")
    #expect(peak != nil)
    #expect(!peak!.peakDays.isEmpty)
    #expect(!peak!.peakHoursUtc.isEmpty)
}

// MARK: - Helpers

private func makeTestBundle() -> Bundle {
    let sourceFile = URL(fileURLWithPath: #filePath)
    let projectRoot = sourceFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let resourcesDir = projectRoot.appendingPathComponent("Resources")
    return Bundle(path: resourcesDir.path) ?? .main
}

private func dayOfWeek(_ weekday: Weekday, at utcHour: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    var date = Date()
    while cal.component(.weekday, from: date) != weekday.rawValue {
        date = cal.date(byAdding: .day, value: 1, to: date)!
    }
    var c = cal.dateComponents([.year, .month, .day], from: date)
    c.hour = utcHour; c.minute = 0
    return cal.date(from: c)!
}

private enum Weekday: Int {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}
