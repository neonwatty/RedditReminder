import Testing
import Foundation
@testable import RedditReminder

@Test func subredditDefaultsToNilOverrides() {
    let sub = Subreddit(name: "r/Test")
    #expect(sub.peakDaysOverride == nil)
    #expect(sub.peakHoursUtcOverride == nil)
}

@Test func subredditPeakDaysOverridePersists() {
    let sub = Subreddit(name: "r/Test", peakDaysOverride: ["mon", "wed", "fri"])
    #expect(sub.peakDaysOverride == ["mon", "wed", "fri"])
}

@Test func subredditPeakHoursOverridePersists() {
    let sub = Subreddit(name: "r/Test", peakHoursUtcOverride: [14, 15, 16, 17, 18])
    #expect(sub.peakHoursUtcOverride == [14, 15, 16, 17, 18])
}

@Test func clearingOverridesSetsNil() {
    let sub = Subreddit(
        name: "r/Test",
        peakDaysOverride: ["mon"],
        peakHoursUtcOverride: [14]
    )
    sub.peakDaysOverride = nil
    sub.peakHoursUtcOverride = nil
    #expect(sub.peakDaysOverride == nil)
    #expect(sub.peakHoursUtcOverride == nil)
}

@Test @MainActor func heuristicsOverrideTakesPriority() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    store.setOverride(for: "r/SideProject", peakDays: ["fri"], peakHoursUtc: [20, 21])
    let peak = store.peakInfo(for: "r/SideProject")
    #expect(peak != nil)
    #expect(peak!.peakDays == ["fri"])
    #expect(peak!.peakHoursUtc == [20, 21])
}

@Test @MainActor func heuristicsClearOverrideFallsBack() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    store.setOverride(for: "r/SideProject", peakDays: ["fri"], peakHoursUtc: [20])
    store.clearOverride(for: "r/SideProject")
    let peak = store.peakInfo(for: "r/SideProject")
    #expect(peak != nil)
    #expect(peak!.peakDays.contains("tue"))
}

@Test @MainActor func isPeakWindowRespectsOverride() {
    let store = HeuristicsStore(bundle: makeTestBundle())
    // Override to only Friday at 20 UTC
    store.setOverride(for: "r/SideProject", peakDays: ["fri"], peakHoursUtc: [20])

    let friday20 = dayOfWeek(.friday, at: 20)
    let tuesday14 = dayOfWeek(.tuesday, at: 14)

    #expect(store.isPeakWindow(for: "r/SideProject", at: friday20))
    // Tuesday 14 was peak by default, but override removed it
    #expect(!store.isPeakWindow(for: "r/SideProject", at: tuesday14))
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
