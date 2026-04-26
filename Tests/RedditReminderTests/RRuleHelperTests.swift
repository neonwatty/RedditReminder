import Testing
import Foundation
@testable import RedditReminder

@Test func weeklyRRuleNextOccurrence() {
  // "Every Saturday" starting from a Wednesday
  let wednesday = calendar(2026, 4, 22, 10, 0) // Wed Apr 22 2026
  let next = RRuleHelper.nextOccurrence(
    rrule: "FREQ=WEEKLY;BYDAY=SA",
    after: wednesday
  )
  #expect(next != nil)
  let cal = Calendar.current
  #expect(cal.component(.weekday, from: next!) == 7) // Saturday
  #expect(next! > wednesday)
}

@Test func weeklyRRuleMultipleOccurrences() {
  let monday = calendar(2026, 4, 20, 10, 0)
  let occurrences = RRuleHelper.nextOccurrences(
    rrule: "FREQ=WEEKLY;BYDAY=SA",
    after: monday,
    count: 3
  )
  #expect(occurrences.count == 3)
  let cal = Calendar.current
  for occ in occurrences {
    #expect(cal.component(.weekday, from: occ) == 7)
  }
}

@Test func dailyRRuleNextOccurrence() {
  let now = calendar(2026, 4, 25, 10, 0)
  let next = RRuleHelper.nextOccurrence(
    rrule: "FREQ=DAILY",
    after: now
  )
  #expect(next != nil)
  let cal = Calendar.current
  let dayDiff = cal.dateComponents([.day], from: now, to: next!).day!
  #expect(dayDiff == 1)
}

@Test func weeklyRRuleSameWeekdayReturnsNextWeek() {
  // Saturday targeting Saturday — should return next Saturday since
  // the algorithm uses `after`'s own time as the occurrence time
  let saturday = calendar(2026, 4, 25, 10, 0) // Sat Apr 25 2026
  let next = RRuleHelper.nextOccurrence(
    rrule: "FREQ=WEEKLY;BYDAY=SA",
    after: saturday
  )
  #expect(next != nil)
  let cal = Calendar.current
  #expect(cal.component(.weekday, from: next!) == 7) // Saturday
  let dayDiff = cal.dateComponents([.day], from: saturday, to: next!).day!
  #expect(dayDiff == 7) // exactly one week later
}

@Test func dailyRRuleMultipleOccurrences() {
  let now = calendar(2026, 4, 25, 10, 0)
  let occurrences = RRuleHelper.nextOccurrences(
    rrule: "FREQ=DAILY",
    after: now,
    count: 3
  )
  #expect(occurrences.count == 3)
  let cal = Calendar.current
  for (i, occ) in occurrences.enumerated() {
    let dayDiff = cal.dateComponents([.day], from: now, to: occ).day!
    #expect(dayDiff == i + 1) // 1, 2, 3 days ahead
  }
}

@Test func invalidRRuleReturnsNil() {
  let now = Date()
  let next = RRuleHelper.nextOccurrence(rrule: "GARBAGE", after: now)
  #expect(next == nil)
}

private func calendar(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
  var c = DateComponents()
  c.year = y
  c.month = m
  c.day = d
  c.hour = h
  c.minute = min
  c.timeZone = TimeZone(identifier: "America/New_York")
  return Calendar.current.date(from: c)!
}
