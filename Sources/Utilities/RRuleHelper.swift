import Foundation

enum RRuleHelper {
  /// Parse a simple RRULE and return the next occurrence after `after`.
  /// Supports: FREQ=WEEKLY;BYDAY=XX and FREQ=DAILY
  static func nextOccurrence(rrule: String, after: Date) -> Date? {
    let occurrences = nextOccurrences(rrule: rrule, after: after, count: 1)
    return occurrences.first
  }

  /// Return the next `count` occurrences of an RRULE after `after`.
  static func nextOccurrences(rrule: String, after: Date, count: Int) -> [Date] {
    guard let parsed = parse(rrule) else { return [] }

    var results: [Date] = []
    let cal = Calendar.current
    var candidate = cal.startOfDay(for: after)

    // Search up to 365 days ahead
    for _ in 0..<365 {
      candidate = cal.date(byAdding: .day, value: 1, to: candidate)!

      switch parsed {
      case .weekly(let targetWeekday):
        let weekday = cal.component(.weekday, from: candidate)
        if weekday == targetWeekday {
          let time = cal.dateComponents([.hour, .minute], from: after)
          var components = cal.dateComponents([.year, .month, .day], from: candidate)
          components.hour = time.hour
          components.minute = time.minute
          if let date = cal.date(from: components), date > after {
            results.append(date)
          }
        }
      case .daily:
        let time = cal.dateComponents([.hour, .minute], from: after)
        var components = cal.dateComponents([.year, .month, .day], from: candidate)
        components.hour = time.hour
        components.minute = time.minute
        if let date = cal.date(from: components), date > after {
          results.append(date)
        }
      }

      if results.count >= count { break }
    }

    return results
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

    switch freq {
    case "WEEKLY":
      guard let byday = parts["BYDAY"] else { return nil }
      guard let weekday = weekdayNumber(byday) else { return nil }
      return .weekly(weekday)
    case "DAILY":
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
