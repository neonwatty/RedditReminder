import Foundation
import Testing
@testable import RedditReminder

private let timingWindowNow = Date(timeIntervalSince1970: 1_700_000_000)

@Test @MainActor func nextWindowOneOffPrioritizedOverRRule() {
    let sub = Subreddit(name: "r/Test")
    let futureDate = Date().addingTimeInterval(3600)
    let event = SubredditEvent(
        name: "Both",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        oneOffDate: futureDate
    )

    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window == futureDate)
}

@Test @MainActor func nextWindowNilForNoRuleNoDate() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Empty", subreddit: sub)
    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window == nil)
}

@Test @MainActor func refreshAssignsCorrectUrgencyToWindows() {
    let sub = Subreddit(name: "r/Test")
    let soon = SubredditEvent(
        name: "Soon",
        subreddit: sub,
        oneOffDate: timingWindowNow.addingTimeInterval(0.25 * 3600)
    )
    let later = SubredditEvent(
        name: "Later",
        subreddit: sub,
        oneOffDate: timingWindowNow.addingTimeInterval(18 * 3600)
    )

    let engine = TimingEngine()
    engine.refresh(events: [soon, later], captures: [], now: timingWindowNow)

    let soonWindow = engine.upcomingWindows.first { $0.event.name == "Soon" }
    let laterWindow = engine.upcomingWindows.first { $0.event.name == "Later" }
    #expect(soonWindow?.urgency == .active)
    #expect(laterWindow?.urgency == .low)
}

@Test @MainActor func leadTimeSubtractedFromNotificationFireDate() {
    let sub = Subreddit(name: "r/Test")
    let eventTime = timingWindowNow.addingTimeInterval(6 * 3600)
    let event = SubredditEvent(
        name: "With Lead",
        subreddit: sub,
        oneOffDate: eventTime,
        reminderLeadMinutes: 60
    )

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [], now: timingWindowNow)

    #expect(engine.upcomingWindows.count == 1)
    let window = engine.upcomingWindows[0]
    #expect(window.eventDate == eventTime)
    let expectedNotifTime = eventTime.addingTimeInterval(-3600)
    #expect(window.notificationFireDate == expectedNotifTime)
}

@Test @MainActor func zeroLeadTimeNotificationFireDateEqualsEventDate() {
    let sub = Subreddit(name: "r/Test")
    let eventTime = timingWindowNow.addingTimeInterval(3 * 3600)
    let event = SubredditEvent(
        name: "No Lead",
        subreddit: sub,
        oneOffDate: eventTime,
        reminderLeadMinutes: 0
    )

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [], now: timingWindowNow)

    #expect(engine.upcomingWindows.count == 1)
    let window = engine.upcomingWindows[0]
    #expect(window.notificationFireDate == window.eventDate)
}

@Test @MainActor func urgencyBasedOnEventDateNotNotificationDate() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(
        name: "FarEvent",
        subreddit: sub,
        oneOffDate: timingWindowNow.addingTimeInterval(18 * 3600),
        reminderLeadMinutes: 120
    )

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [], now: timingWindowNow)

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows[0].urgency == .low)
}
