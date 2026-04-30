import Foundation
import Testing
@testable import RedditReminder

@Test func weeklyRRuleAllWeekdays() {
    let monday = rruleEdgeLocalDate(2026, 4, 20, 10, 0)
    let cal = Calendar.current
    let weekdays = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
    let expectedWeekday = [1, 2, 3, 4, 5, 6, 7]

    for (abbrev, expected) in zip(weekdays, expectedWeekday) {
        let next = RRuleHelper.nextOccurrence(
            rrule: "FREQ=WEEKLY;BYDAY=\(abbrev)",
            after: monday
        )
        #expect(next != nil)
        #expect(cal.component(.weekday, from: next!) == expected)
    }
}

@Test func bydayIsCaseInsensitive() {
    let now = rruleEdgeDate(2026, 4, 22, 10, 0)
    let lower = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=sa", after: now)
    let upper = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=SA", after: now)
    let mixed = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=Sa", after: now)
    #expect(lower == upper)
    #expect(upper == mixed)
}

@Test func dailyOccurrencesPreserveTimeComponent() {
    let start = rruleEdgeLocalDate(2026, 4, 25, 14, 30)
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

@Test func weeklyOccurrencesPreserveTimeComponent() {
    let start = rruleEdgeLocalDate(2026, 4, 22, 9, 15)
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=WEEKLY;BYDAY=FR",
        after: start,
        count: 2
    )
    let cal = Calendar.current
    for occ in occurrences {
        #expect(cal.component(.hour, from: occ) == 9)
        #expect(cal.component(.minute, from: occ) == 15)
        #expect(cal.component(.weekday, from: occ) == 6)
    }
}

@Test func weeklyOccurrencesAreSevenDaysApart() {
    let start = rruleEdgeDate(2026, 4, 22, 10, 0)
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: start,
        count: 4
    )
    #expect(occurrences.count == 4)
    for i in 1..<occurrences.count {
        let diff = occurrences[i].timeIntervalSince(occurrences[i - 1])
        #expect(abs(diff - 7 * 86400) < 7200)
    }
}

@Test func sameWeekdayFutureTimeReturnsTodayUsingFixedTime() {
    let satMidnight = rruleEdgeLocalDate(2026, 4, 25, 0, 0)

    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: satMidnight
    )
    #expect(next != nil)
    let cal = Calendar.current
    let dayDiff = cal.dateComponents([.day], from: satMidnight, to: next!).day!
    #expect(dayDiff == 7)
}

@Test func fixedUtcWeeklyOccurrenceDoesNotUseAfterTime() {
    let after = rruleEdgeDate(2026, 4, 22, 9, 37)
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: after,
        hour: 14,
        minute: 0,
        timeZone: TimeZone(identifier: "UTC")!
    )

    #expect(next != nil)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    #expect(cal.component(.weekday, from: next!) == 7)
    #expect(cal.component(.hour, from: next!) == 14)
    #expect(cal.component(.minute, from: next!) == 0)
}

@Test func fixedUtcDailyOccurrenceReturnsTodayWhenTimeIsFuture() {
    let after = rruleEdgeDate(2026, 4, 22, 9, 37)
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=DAILY",
        after: after,
        hour: 14,
        minute: 0,
        timeZone: TimeZone(identifier: "UTC")!
    )

    #expect(next != nil)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    #expect(cal.component(.day, from: next!) == cal.component(.day, from: after))
    #expect(cal.component(.hour, from: next!) == 14)
    #expect(cal.component(.minute, from: next!) == 0)
}

@Test func fixedUtcDailyOccurrenceReturnsTomorrowWhenTimeHasPassed() {
    let after = rruleEdgeDate(2026, 4, 22, 15, 37)
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=DAILY",
        after: after,
        hour: 14,
        minute: 0,
        timeZone: TimeZone(identifier: "UTC")!
    )

    #expect(next != nil)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let afterStart = cal.startOfDay(for: after)
    let nextStart = cal.startOfDay(for: next!)
    let dayDiff = cal.dateComponents([.day], from: afterStart, to: nextStart).day
    #expect(dayDiff == 1)
    #expect(cal.component(.hour, from: next!) == 14)
    #expect(cal.component(.minute, from: next!) == 0)
}

@Test func fixedTimezoneDailySkipsNonexistentSpringForwardTime() {
    let timeZone = TimeZone(identifier: "America/New_York")!
    let after = rruleDate(2026, 3, 7, 12, 0, timeZone: timeZone)
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=DAILY",
        after: after,
        hour: 2,
        minute: 30,
        timeZone: timeZone
    )

    #expect(next != nil)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    #expect(cal.component(.day, from: next!) == 9)
    #expect(cal.component(.hour, from: next!) == 2)
    #expect(cal.component(.minute, from: next!) == 30)
}

@Test func fixedTimezoneWeeklySkipsNonexistentSpringForwardTime() {
    let timeZone = TimeZone(identifier: "America/New_York")!
    let after = rruleDate(2026, 3, 1, 12, 0, timeZone: timeZone)
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=WEEKLY;BYDAY=SU",
        after: after,
        hour: 2,
        minute: 30,
        timeZone: timeZone
    )

    #expect(next != nil)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    #expect(cal.component(.day, from: next!) == 15)
    #expect(cal.component(.hour, from: next!) == 2)
    #expect(cal.component(.minute, from: next!) == 30)
}

@Test func fixedTimezoneDailyPreservesFallBackWallClockTime() {
    let timeZone = TimeZone(identifier: "America/New_York")!
    let after = rruleDate(2026, 11, 1, 0, 30, timeZone: timeZone)
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=DAILY",
        after: after,
        hour: 1,
        minute: 30,
        timeZone: timeZone
    )

    #expect(next != nil)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    #expect(cal.component(.day, from: next!) == 1)
    #expect(cal.component(.hour, from: next!) == 1)
    #expect(cal.component(.minute, from: next!) == 30)
}
