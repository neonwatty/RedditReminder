import Testing
import Foundation
@testable import RedditReminder

// MARK: - refresh() edge cases

@Test @MainActor func refreshWithNoEventsProducesEmpty() {
    let engine = TimingEngine()
    engine.refresh(events: [], captures: [])
    #expect(engine.upcomingWindows.isEmpty)
}

@Test @MainActor func refreshWithNoCapturesShowsZeroCounts() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(
        name: "Soon",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(3600)
    )

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [])

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows[0].matchingCaptureCount == 0)
}

@Test @MainActor func refreshExcludesInactiveEvents() {
    let sub = Subreddit(name: "r/Test")
    let active = SubredditEvent(
        name: "Active",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(3600)
    )
    let inactive = SubredditEvent(
        name: "Inactive",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(7200),
        isActive: false
    )

    let engine = TimingEngine()
    engine.refresh(events: [active, inactive], captures: [])

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows[0].event.name == "Active")
}

@Test @MainActor func refreshExcludesEventsBeyondHorizon() {
    let sub = Subreddit(name: "r/Test")
    let within = SubredditEvent(
        name: "Within",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(12 * 3600) // 12h
    )
    let beyond = SubredditEvent(
        name: "Beyond",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(25 * 3600) // 25h
    )

    let engine = TimingEngine()
    engine.refresh(events: [within, beyond], captures: [])

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows[0].event.name == "Within")
}

@Test @MainActor func refreshExcludesExpiredOneOffEvents() {
    let sub = Subreddit(name: "r/Test")
    let expired = SubredditEvent(
        name: "Expired",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(-3600) // 1h ago
    )

    let engine = TimingEngine()
    engine.refresh(events: [expired], captures: [])

    #expect(engine.upcomingWindows.isEmpty)
}

@Test @MainActor func refreshHandlesEventWithNilSubreddit() {
    // SubredditEvent.subreddit is optional in the model — if nil, count should be 0
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(
        name: "Orphan",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(3600)
    )
    // Simulate orphaned event by clearing the subreddit reference
    event.subreddit = nil

    let capture = Capture(text: "Has captures", subreddits: [sub])

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [capture])

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows[0].matchingCaptureCount == 0)
}

@Test @MainActor func refreshMixesRecurringAndOneOffEvents() {
    let sub = Subreddit(name: "r/Test")
    let oneOff = SubredditEvent(
        name: "Launch Day",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(6 * 3600)
    )
    let alsoOneOff = SubredditEvent(
        name: "Second Event",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(12 * 3600)
    )

    let engine = TimingEngine()
    engine.refresh(events: [oneOff, alsoOneOff], captures: [])

    #expect(engine.upcomingWindows.count == 2)
}

@Test @MainActor func refreshCountsMultiSubredditCapture() {
    let sub1 = Subreddit(name: "r/A")
    let sub2 = Subreddit(name: "r/B")
    let event1 = SubredditEvent(name: "E1", subreddit: sub1, oneOffDate: Date().addingTimeInterval(3600))
    let event2 = SubredditEvent(name: "E2", subreddit: sub2, oneOffDate: Date().addingTimeInterval(7200))

    // Capture tagged to both subreddits should count for both
    let capture = Capture(text: "Cross-posted", subreddits: [sub1, sub2])

    let engine = TimingEngine()
    engine.refresh(events: [event1, event2], captures: [capture])

    #expect(engine.upcomingWindows.count == 2)
    for window in engine.upcomingWindows {
        #expect(window.matchingCaptureCount == 1)
    }
}

@Test @MainActor func refreshIgnoresPostedCaptures() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Post", subreddit: sub, oneOffDate: Date().addingTimeInterval(3600))

    let queued = Capture(text: "Ready", subreddits: [sub])
    let posted = Capture(text: "Done", subreddits: [sub])
    posted.markAsPosted()

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [queued, posted])

    #expect(engine.upcomingWindows[0].matchingCaptureCount == 1)
}

// MARK: - Urgency level boundaries

@Test @MainActor func urgencyBoundaryAtExactlyZero() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0.0) == .active)
}

@Test @MainActor func urgencyBoundaryAtHalfHour() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0.5) == .high)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0.49) == .active)
}

@Test @MainActor func urgencyBoundaryAtTwoHours() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 2.0) == .medium)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 1.99) == .high)
}

@Test @MainActor func urgencyBoundaryAtTwelveHours() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 12.0) == .low)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 11.99) == .medium)
}

@Test @MainActor func urgencyBoundaryAtTwentyFourHours() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 24.0) == .none)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 23.99) == .low)
}

// MARK: - nextWindow static

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
    // oneOffDate wins when both are set
    #expect(window == futureDate)
}

@Test @MainActor func nextWindowNilForNoRuleNoDate() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Empty", subreddit: sub)
    // Neither rrule nor oneOffDate
    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window == nil)
}

@Test @MainActor func refreshAssignsCorrectUrgencyToWindows() {
    let sub = Subreddit(name: "r/Test")
    let soon = SubredditEvent(
        name: "Soon",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(0.25 * 3600) // 15 min
    )
    let later = SubredditEvent(
        name: "Later",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(18 * 3600) // 18h
    )

    let engine = TimingEngine()
    engine.refresh(events: [soon, later], captures: [])

    let soonWindow = engine.upcomingWindows.first { $0.event.name == "Soon" }
    let laterWindow = engine.upcomingWindows.first { $0.event.name == "Later" }
    #expect(soonWindow?.urgency == .active)
    #expect(laterWindow?.urgency == .low)
}
