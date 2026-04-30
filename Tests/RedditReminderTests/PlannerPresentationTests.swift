import Foundation
import Testing

@testable import RedditReminder

@Test @MainActor func plannerPresentationGroupsWindowsByDay() {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29, hour: 12))!
  let subreddit = Subreddit(name: "r/Test")
  let todayEvent = SubredditEvent(
    name: "Today",
    subreddit: subreddit,
    oneOffDate: now.addingTimeInterval(3600)
  )
  let tomorrowEvent = SubredditEvent(
    name: "Tomorrow",
    subreddit: subreddit,
    oneOffDate: now.addingTimeInterval(26 * 3600)
  )
  let windows = [
    plannerWindow(event: tomorrowEvent, date: tomorrowEvent.oneOffDate!),
    plannerWindow(event: todayEvent, date: todayEvent.oneOffDate!),
  ]

  let groups = PlannerPresentation.dayGroups(from: windows, now: now, calendar: calendar)

  #expect(groups.count == 2)
  #expect(groups[0].title == "Today")
  #expect(groups[0].windows[0].event.name == "Today")
  #expect(groups[1].title == "Tomorrow")
}

@Test func plannerPresentationReadinessTextPluralizesCounts() {
  #expect(PlannerPresentation.readinessText(for: 0) == "Queue empty")
  #expect(PlannerPresentation.readinessText(for: 1) == "1 capture ready")
  #expect(PlannerPresentation.readinessText(for: 2) == "2 captures ready")
}

@MainActor
private func plannerWindow(event: SubredditEvent, date: Date) -> TimingEngine.UpcomingWindow {
  TimingEngine.UpcomingWindow(
    event: event,
    eventDate: date,
    notificationFireDate: date,
    urgency: .low,
    matchingCaptureCount: 0
  )
}
