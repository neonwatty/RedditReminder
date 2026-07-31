import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import RedditReminder

private final class HeuristicsRecordingNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
  private(set) var removedIdentifiers: [[String]] = []

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
  func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {}
  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    removedIdentifiers.append(identifiers)
  }
  func removeAllPendingNotificationRequests() {}
  func getAuthorizationStatus() async -> UNAuthorizationStatus { .authorized }
}

private func makeTestBundle() -> Bundle {
  makePeakTimesTestBundle()
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

@Test @MainActor func syncGeneratedEventsCancelsNotificationsForRemovedGeneratedEvents() throws {
  let container = try makeContainer()
  let context = ModelContext(container)
  let sub = Subreddit(name: "r/SideProject")
  context.insert(sub)
  try context.save()

  let store = HeuristicsStore(bundle: makeTestBundle())
  try store.syncGeneratedEvents(for: sub, context: context, defaultLeadTimeMinutes: 60)
  let originalEvents = try context.fetch(FetchDescriptor<SubredditEvent>())
  #expect(originalEvents.count == 6)

  let center = HeuristicsRecordingNotificationCenter()
  let service = NotificationService(center: center)
  sub.peakDaysOverride = ["mon"]
  sub.peakHoursUtcOverride = [9]
  try context.save()

  try store.syncGeneratedEvents(
    for: sub,
    context: context,
    defaultLeadTimeMinutes: 60,
    notificationService: service
  )

  let removedIds = Set(center.removedIdentifiers.flatMap { $0 })
  for event in originalEvents {
    #expect(removedIds.contains(AppNotificationIdentifiers.windowRequestId(eventId: event.id.uuidString)))
    #expect(removedIds.contains(AppNotificationIdentifiers.nudgeRequestId(eventId: event.id.uuidString)))
  }
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
