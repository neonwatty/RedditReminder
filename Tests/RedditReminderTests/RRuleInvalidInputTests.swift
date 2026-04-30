import Foundation
import Testing
@testable import RedditReminder

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

@Test func multipleBydayValuesReturnsNil() {
    let now = Date()
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=MO,WE,FR", after: now)
    #expect(next == nil)
}

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

@Test func unsupportedDailyIntervalReturnsNil() {
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=DAILY;INTERVAL=2", after: Date())
    #expect(next == nil)
}

@Test func unsupportedWeeklyUntilReturnsNil() {
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231T000000Z", after: Date())
    #expect(next == nil)
}

@Test func unknownRRulePropertyReturnsNil() {
    let next = RRuleHelper.nextOccurrence(rrule: "FREQ=DAILY;WKST=MO", after: Date())
    #expect(next == nil)
}

@Test func countZeroReturnsEmpty() {
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=DAILY",
        after: Date(),
        count: 0
    )
    #expect(occurrences.isEmpty)
}

@Test func countOneMatchesNextOccurrence() {
    let now = rruleEdgeDate(2026, 4, 22, 10, 0)
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
