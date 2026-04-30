import Foundation

struct PlannerDayGroup {
  let day: Date
  let title: String
  let windows: [TimingEngine.UpcomingWindow]
}

enum PlannerPresentation {
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
}
