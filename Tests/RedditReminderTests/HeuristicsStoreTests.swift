import Testing
import Foundation
import SwiftData
@testable import RedditReminder

// Helper: create a Bundle-like loader from the known Resources path at test time.
// Tests run with TEST_HOST (bundle loader), so Bundle.main is the app bundle.
// Rather than depend on the JSON being copied into the app bundle during build,
// we load from the source tree path. In production the app uses Bundle.main normally.
private func makeTestBundle() -> Bundle {
  // Walk up from this file's compile-time path to find Resources/peak-times.json.
  // #filePath resolves to the absolute source file path at compile time.
  let sourceFile = URL(fileURLWithPath: #filePath)
  // HeuristicsStoreTests.swift → Tests/RedditReminderTests/ → Tests/ → project root
  let projectRoot = sourceFile
    .deletingLastPathComponent()  // RedditReminderTests/
    .deletingLastPathComponent()  // Tests/
    .deletingLastPathComponent()  // project root
  let resourcesDir = projectRoot.appendingPathComponent("Resources")

  // Build a temporary Bundle from that directory so bundle.url(forResource:) works.
  return Bundle(path: resourcesDir.path) ?? .main
}

@Test @MainActor func loadBundledHeuristics() {
  let store = HeuristicsStore(bundle: makeTestBundle())
  let peak = store.peakInfo(for: "r/SideProject")
  #expect(peak != nil)
  #expect(peak!.peakDays.contains("tue"))
  #expect(peak!.peakDays.contains("sat"))
  #expect(peak!.peakHoursUtc.contains(14))
}

@Test @MainActor func unknownSubredditReturnsNil() {
  let store = HeuristicsStore(bundle: makeTestBundle())
  let peak = store.peakInfo(for: "r/nonexistent")
  #expect(peak == nil)
}

@Test @MainActor func userOverrideTakesPrecedence() {
  let store = HeuristicsStore(bundle: makeTestBundle())
  store.setOverride(
    for: "r/SideProject",
    peakDays: ["mon"],
    peakHoursUtc: [9, 10]
  )
  let peak = store.peakInfo(for: "r/SideProject")
  #expect(peak != nil)
  #expect(peak!.peakDays == ["mon"])
  #expect(peak!.peakHoursUtc == [9, 10])
}

@Test @MainActor func clearOverrideFallsBackToBundled() {
  let store = HeuristicsStore(bundle: makeTestBundle())
  store.setOverride(for: "r/SideProject", peakDays: ["mon"], peakHoursUtc: [9])
  store.clearOverride(for: "r/SideProject")
  let peak = store.peakInfo(for: "r/SideProject")
  #expect(peak!.peakDays.contains("tue"))
}

@Test @MainActor func isCurrentlyPeakHour() {
  let store = HeuristicsStore(bundle: makeTestBundle())
  let tuesday = dayOfWeek(.tuesday, at: 14)
  let offPeakTime = dayOfWeek(.tuesday, at: 6)

  #expect(store.isPeakWindow(for: "r/SideProject", at: tuesday))
  #expect(!store.isPeakWindow(for: "r/SideProject", at: offPeakTime))
}

@Test @MainActor func syncGeneratedEventsCreatesPeakWindows() throws {
  let container = try makeContainer()
  let context = ModelContext(container)
  let sub = Subreddit(name: "r/SideProject")
  context.insert(sub)
  try context.save()

  let store = HeuristicsStore(bundle: makeTestBundle())
  try store.syncGeneratedEvents(for: sub, context: context, defaultLeadTimeMinutes: 30)

  let events = try context.fetch(FetchDescriptor<SubredditEvent>())
  #expect(events.count == 6)
  #expect(events.allSatisfy { $0.isGeneratedFromHeuristics })
  #expect(events.allSatisfy { $0.recurrenceTimeZoneIdentifier == "UTC" })
  #expect(events.allSatisfy { $0.reminderLeadMinutes == 30 })
  #expect(Set(events.compactMap(\.recurrenceHour)) == [14, 15, 16])
}

@Test @MainActor func syncGeneratedEventsFollowsOverridesAndRemovesStaleEvents() throws {
  let container = try makeContainer()
  let context = ModelContext(container)
  let sub = Subreddit(name: "r/SideProject")
  context.insert(sub)
  try context.save()

  let store = HeuristicsStore(bundle: makeTestBundle())
  try store.syncGeneratedEvents(for: sub, context: context, defaultLeadTimeMinutes: 60)
  #expect(try context.fetchCount(FetchDescriptor<SubredditEvent>()) == 6)

  sub.peakDaysOverride = ["mon"]
  sub.peakHoursUtcOverride = [9]
  try context.save()
  try store.syncGeneratedEvents(for: sub, context: context, defaultLeadTimeMinutes: 120)

  let events = try context.fetch(FetchDescriptor<SubredditEvent>())
  #expect(events.count == 1)
  #expect(events[0].rrule == "FREQ=WEEKLY;BYDAY=MO")
  #expect(events[0].recurrenceHour == 9)
  #expect(events[0].reminderLeadMinutes == 120)
}

private func makeContainer() throws -> ModelContainer {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  return try ModelContainer(
    for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
    configurations: config
  )
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
