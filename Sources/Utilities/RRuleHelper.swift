import Foundation

enum RRuleHelper {
  /// Parse a simple RRULE and return the next occurrence after `after`.
  /// Supports: FREQ=WEEKLY;BYDAY=XX and FREQ=DAILY
  static func nextOccurrence(rrule: String, after: Date) -> Date? {
    let occurrences = nextOccurrences(rrule: rrule, after: after, count: 1)
    return occurrences.first
  }

  static func nextOccurrence(
    rrule: String,
    after: Date,
    hour: Int,
    minute: Int,
    timeZone: TimeZone
  ) -> Date? {
    nextOccurrences(
      rrule: rrule,
      after: after,
      count: 1,
      hour: hour,
      minute: minute,
      timeZone: timeZone
    ).first
  }

  /// Return the next `count` occurrences of an RRULE after `after`.
  static func nextOccurrences(rrule: String, after: Date, count: Int) -> [Date] {
    guard let parsed = parse(rrule) else { return [] }

    let cal = Calendar.current
    let time = cal.dateComponents([.hour, .minute], from: after)

    switch parsed {
    case .daily:
      return nextDailyOccurrences(after: after, time: time, count: count, cal: cal)
    case .weekly(let targetWeekday):
      return nextWeeklyOccurrences(after: after, targetWeekday: targetWeekday, time: time, count: count, cal: cal)
    }
  }

  static func nextOccurrences(
    rrule: String,
    after: Date,
    count: Int,
    hour: Int,
    minute: Int,
    timeZone: TimeZone
  ) -> [Date] {
    guard let parsed = parse(rrule) else { return [] }

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    let time = DateComponents(hour: min(23, max(0, hour)), minute: min(59, max(0, minute)))

    switch parsed {
    case .daily:
      return nextDailyOccurrences(after: after, time: time, count: count, cal: cal)
    case .weekly(let targetWeekday):
      return nextWeeklyOccurrences(after: after, targetWeekday: targetWeekday, time: time, count: count, cal: cal)
    }
  }

  private static func nextDailyOccurrences(
    after: Date, time: DateComponents, count: Int, cal: Calendar
  ) -> [Date] {
    guard count > 0 else { return [] }

    var results: [Date] = []
    guard var day = cal.date(byAdding: .day, value: 0, to: cal.startOfDay(for: after)) else { return [] }

    while results.count < count {
      if let date = date(on: day, time: time, cal: cal), date > after {
        results.append(date)
      }
      guard let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { break }
      day = nextDay
    }
    return results
  }

  private static func nextWeeklyOccurrences(
    after: Date, targetWeekday: Int, time: DateComponents, count: Int, cal: Calendar
  ) -> [Date] {
    guard count > 0 else { return [] }

    var results: [Date] = []
    let currentWeekday = cal.component(.weekday, from: after)

    // Calculate days until the next target weekday (skip today unless
    // its target time hasn't passed yet)
    var daysAhead = (targetWeekday - currentWeekday + 7) % 7
    if daysAhead == 0 { daysAhead = 7 } // same weekday → next week by default

    // Check if today's target time is still in the future
    if daysAhead == 7 {
      var todayComponents = cal.dateComponents([.year, .month, .day], from: after)
      todayComponents.hour = time.hour
      todayComponents.minute = time.minute
      if let todayDate = cal.date(from: todayComponents), todayDate > after {
        daysAhead = 0
      }
    }

    guard var candidate = cal.date(byAdding: .day, value: daysAhead, to: cal.startOfDay(for: after)) else { return [] }

    while results.count < count {
      if let date = date(on: candidate, time: time, cal: cal), date > after {
        results.append(date)
      }
      guard let nextCandidate = cal.date(byAdding: .day, value: 7, to: candidate) else { break }
      candidate = nextCandidate
    }
    return results
  }

  private static func date(on day: Date, time: DateComponents, cal: Calendar) -> Date? {
    var components = cal.dateComponents([.year, .month, .day], from: day)
    components.hour = time.hour
    components.minute = time.minute
    guard let date = cal.date(from: components) else { return nil }

    let resolved = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    guard resolved.year == components.year,
          resolved.month == components.month,
          resolved.day == components.day,
          resolved.hour == components.hour,
          resolved.minute == components.minute else {
      return nil
    }
    return date
  }

  private enum ParsedRule {
    case weekly(Int)  // weekday: 1=Sunday, 7=Saturday
    case daily
  }

  private static func parse(_ rrule: String) -> ParsedRule? {
    let parts = rrule.split(separator: ";").reduce(into: [String: String]()) { dict, part in
      let kv = part.split(separator: "=", maxSplits: 1)
      if kv.count == 2 { dict[String(kv[0])] = String(kv[1]) }
    }

    guard let freq = parts["FREQ"] else { return nil }
    let supportedKeys: Set<String>

    switch freq {
    case "WEEKLY":
      supportedKeys = ["FREQ", "BYDAY"]
      guard Set(parts.keys).isSubset(of: supportedKeys) else { return nil }
      guard let byday = parts["BYDAY"] else { return nil }
      guard let weekday = weekdayNumber(byday) else { return nil }
      return .weekly(weekday)
    case "DAILY":
      supportedKeys = ["FREQ"]
      guard Set(parts.keys).isSubset(of: supportedKeys) else { return nil }
      return .daily
    default:
      return nil
    }
  }

  /// Convert RRULE day abbreviation to Calendar weekday (1=Sun, 7=Sat)
  private static func weekdayNumber(_ abbrev: String) -> Int? {
    switch abbrev.uppercased() {
    case "SU": return 1
    case "MO": return 2
    case "TU": return 3
    case "WE": return 4
    case "TH": return 5
    case "FR": return 6
    case "SA": return 7
    default: return nil
    }
  }
}
