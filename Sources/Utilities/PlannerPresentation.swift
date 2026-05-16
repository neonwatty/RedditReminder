import Foundation

struct PlannerDayGroup {
  let day: Date
  let title: String
  let windows: [TimingEngine.UpcomingWindow]
}

struct PlannerCalendarDay {
  let day: Date
  let title: String
  let dayNumber: String
  let windows: [TimingEngine.UpcomingWindow]
}

enum PlannerPresentation {
  static let createCaptureIdentifierPrefix = "planner.createCapture"

  static func dayGroups(
    from windows: [TimingEngine.UpcomingWindow],
    now: Date = Date(),
    calendar inputCalendar: Calendar = .current
  ) -> [PlannerDayGroup] {
    var calendar = inputCalendar
    calendar.timeZone = inputCalendar.timeZone

    let grouped = Dictionary(grouping: windows) { window in
      calendar.startOfDay(for: window.eventDate)
    }

    return grouped.keys.sorted().map { day in
      PlannerDayGroup(
        day: day,
        title: dayTitle(for: day, now: now, calendar: calendar),
        windows: (grouped[day] ?? []).sorted { $0.eventDate < $1.eventDate }
      )
    }
  }

  static func dayTitle(
    for day: Date,
    now: Date = Date(),
    calendar inputCalendar: Calendar = .current
  ) -> String {
    var calendar = inputCalendar
    calendar.timeZone = inputCalendar.timeZone

    let today = calendar.startOfDay(for: now)
    if day == today {
      return "Today"
    }
    if day == calendar.date(byAdding: .day, value: 1, to: today) {
      return "Tomorrow"
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateFormat = "EEE, MMM d"
    return formatter.string(from: day)
  }

  static func readinessText(for count: Int) -> String {
    count == 0 ? "Queue empty" : "\(count) capture\(count == 1 ? "" : "s") ready"
  }

  static func calendarWindowLabel(subredditName: String?, timeText: String) -> String {
    guard let subredditName, !subredditName.isEmpty else { return timeText }
    return "\(timeText) \(subredditName)"
  }

  static func createCaptureIdentifier(subredditId: UUID?) -> String {
    guard let subredditId else { return createCaptureIdentifierPrefix }
    return "\(createCaptureIdentifierPrefix).\(subredditId.uuidString)"
  }

  static func calendarDays(
    from windows: [TimingEngine.UpcomingWindow],
    now: Date = Date(),
    days: Int = 7,
    calendar inputCalendar: Calendar = .current
  ) -> [PlannerCalendarDay] {
    var calendar = inputCalendar
    calendar.timeZone = inputCalendar.timeZone

    let start = calendar.startOfDay(for: now)
    let grouped = Dictionary(grouping: windows) { window in
      calendar.startOfDay(for: window.eventDate)
    }

    let dayNumberFormatter = DateFormatter()
    dayNumberFormatter.calendar = calendar
    dayNumberFormatter.dateFormat = "d"

    return (0..<max(1, days)).compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
        return nil
      }
      return PlannerCalendarDay(
        day: day,
        title: dayTitle(for: day, now: now, calendar: calendar),
        dayNumber: dayNumberFormatter.string(from: day),
        windows: (grouped[day] ?? []).sorted { $0.eventDate < $1.eventDate }
      )
    }
  }
}
