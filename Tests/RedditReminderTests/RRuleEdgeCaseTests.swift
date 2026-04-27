import Testing
import Foundation
@testable import RedditReminder

// MARK: - Unsupported frequencies

@Test func monthlyRRuleReturnsNil() {
    let now = Date()
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=MONTHLY;BYMONTHDAY=15", after: now)
    #expect(next == nil)
}

@Test func yearlyRRuleReturnsNil() {
    let now = Date()
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=YEARLY", after: now)
    #expect(next == nil)
}

@Test func weeklyWithoutBydayReturnsNil() {
    let now = Date()
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY", after: now)
    #expect(next == nil)
}

// MARK: - Multiple BYDAY (unsupported — should return nil)

@Test func multipleBydayValuesReturnsNil() {
    let now = Date()
    // Current parser only supports single BYDAY
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=MO,WE,FR", after: now)
    #expect(next == nil)
}

// MARK: - Malformed input

@Test func emptyStringReturnsNil() {
    let next = RRuleHelper.nextOccurrence(rrule: "", after: Date())
    #expect(next == nil)
}

@Test func missingFreqReturnsNil() {
    let next = RRuleHelper.nextOccurrence(rrule: "BYDAY=SA", after: Date())
    #expect(next == nil)
}

@Test func invalidBydayAbbrevReturnsNil() {
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=XX", after: Date())
    #expect(next == nil)
}

// MARK: - Count edge cases

@Test func countZeroReturnsEmpty() {
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=DAILY",
        after: Date(),
        count: 0
    )
    #expect(occurrences.isEmpty)
}

@Test func countOneMatchesNextOccurrence() {
    let now = calendar(2026, 4, 22, 10, 0) // Wednesday
    let single = RRuleHelper.nextOccurrences(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: now,
        count: 1
    )
    let direct = RRuleHelper.nextOccurrence(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: now
    )
    #expect(single.count == 1)
    #expect(single.first == direct)
}

// MARK: - All 7 weekdays

@Test func weeklyRRuleAllWeekdays() {
    // Use local timezone so weekday assertions match Calendar.current
    let monday = localDate(2026, 4, 20, 10, 0) // Monday Apr 20 2026 local
    let cal = Calendar.current
    let weekdays = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
    let expectedWeekday = [1, 2, 3, 4, 5, 6, 7] // Calendar weekday numbers

    for (abbrev, expected) in zip(weekdays, expectedWeekday) {
        let next = RRuleHelper.nextOccurrence(
            rrule: "FREQ=WEEKLY;BYDAY=\(abbrev)",
            after: monday
        )
        #expect(next != nil)
        #expect(cal.component(.weekday, from: next!) == expected)
    }
}

// MARK: - Case insensitivity

@Test func bydayIsCaseInsensitive() {
    let now = calendar(2026, 4, 22, 10, 0)
    let lower = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=sa", after: now)
    let upper = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=SA", after: now)
    let mixed = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=Sa", after: now)
    #expect(lower == upper)
    #expect(upper == mixed)
}

// MARK: - Daily occurrences preserve time

@Test func dailyOccurrencesPreserveTimeComponent() {
    // Use local timezone so Calendar.current extracts the same hour/minute
    let start = localDate(2026, 4, 25, 14, 30) // 2:30 PM local
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=DAILY",
        after: start,
        count: 3
    )
    let cal = Calendar.current
    for occ in occurrences {
        #expect(cal.component(.hour, from: occ) == 14)
        #expect(cal.component(.minute, from: occ) == 30)
    }
}

// MARK: - Weekly occurrences preserve time

@Test func weeklyOccurrencesPreserveTimeComponent() {
    // Use local timezone — RRuleHelper uses Calendar.current for time extraction
    let start = localDate(2026, 4, 22, 9, 15) // Wed 9:15 AM local
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=WEEKLY;BYDAY=FR",
        after: start,
        count: 2
    )
    let cal = Calendar.current
    for occ in occurrences {
        #expect(cal.component(.hour, from: occ) == 9)
        #expect(cal.component(.minute, from: occ) == 15)
        #expect(cal.component(.weekday, from: occ) == 6) // Friday
    }
}

// MARK: - Weekly spacing

@Test func weeklyOccurrencesAreSevenDaysApart() {
    let start = calendar(2026, 4, 22, 10, 0) // Wednesday
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: start,
        count: 4
    )
    #expect(occurrences.count == 4)
    for i in 1..<occurrences.count {
        let diff = occurrences[i].timeIntervalSince(occurrences[i - 1])
        // Should be exactly 7 days (within a few seconds for DST)
        #expect(abs(diff - 7 * 86400) < 7200) // allow up to 2h for DST shifts
    }
}

// MARK: - Same weekday, future time today

@Test func sameWeekdayFutureTimeReturnsTodayUsingFixedTime() {
    // Construct a Saturday at midnight local time
    let satMidnight = localDate(2026, 4, 25, 0, 0) // Saturday midnight local

    // The occurrence time is derived from satMidnight (h=0, m=0).
    // Same weekday → default to next week. todayDate (Sat 00:00) > after (Sat 00:00) is false,
    // so it stays at next week.
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: satMidnight
    )
    #expect(next != nil)
    let cal = Calendar.current
    let dayDiff = cal.dateComponents([.day], from: satMidnight, to: next!).day!
    #expect(dayDiff == 7) // next week
}

// MARK: - Date construction helpers

/// Matches RRuleHelperTests convention — fixed date in America/New_York.
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

/// Fixed date in local timezone — use when testing time preservation
/// (RRuleHelper extracts hour/minute via Calendar.current).
private func localDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    var c = DateComponents()
    c.year = y
    c.month = m
    c.day = d
    c.hour = h
    c.minute = min
    c.timeZone = Calendar.current.timeZone
    return Calendar.current.date(from: c)!
}
