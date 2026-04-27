import Testing
import Foundation
@testable import RedditReminder

@Test @MainActor func urgencyFromHoursAway() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 30) == .none)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 18) == .low)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 6) == .medium)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 1) == .high)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0) == .active)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: -1) == .expired)
}

@Test @MainActor func upcomingWindowForEvent() {
    let sub = Subreddit(name: "r/SideProject")
    let event = SubredditEvent(
        name: "Show-off Saturday",
        subreddit: sub,
        rrule: "FREQ=WEEKLY;BYDAY=SA"
    )
    let now = Date()
    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)
    #expect(window! > now)

    let cal = Calendar.current
    #expect(cal.component(.weekday, from: window!) == 7) // Saturday
}

@Test @MainActor func upcomingWindowForOneOff() {
    let sub = Subreddit(name: "r/SideProject")
    let futureDate = Date().addingTimeInterval(86400 * 3)
    let event = SubredditEvent(
        name: "Launch Day",
        subreddit: sub,
        oneOffDate: futureDate
    )
    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window != nil)
    #expect(window == futureDate)
}

@Test @MainActor func expiredOneOffReturnsNil() {
    let sub = Subreddit(name: "r/SideProject")
    let pastDate = Date().addingTimeInterval(-86400)
    let event = SubredditEvent(
        name: "Old Launch",
        subreddit: sub,
        oneOffDate: pastDate
    )
    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window == nil)
}

@Test @MainActor func refreshCountsQueuedCapturesBySubreddit() {
    let sub1 = Subreddit(name: "r/SideProject")
    let sub2 = Subreddit(name: "r/MacApps")

    let fireDate = Date().addingTimeInterval(6 * 3600)
    let event = SubredditEvent(name: "Post time", subreddit: sub1, oneOffDate: fireDate)

    let queued1 = Capture(text: "Cap 1", subreddits: [sub1])
    let queued2 = Capture(text: "Cap 2", subreddits: [sub1, sub2])
    let posted = Capture(text: "Cap 3", subreddits: [sub1])
    posted.markAsPosted()

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [queued1, queued2, posted])

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows.first?.matchingCaptureCount == 2)
}

@Test @MainActor func refreshExcludesCapturesForOtherSubreddits() {
    let sub1 = Subreddit(name: "r/SideProject")
    let sub2 = Subreddit(name: "r/MacApps")

    let fireDate = Date().addingTimeInterval(6 * 3600)
    let event = SubredditEvent(name: "Post time", subreddit: sub2, oneOffDate: fireDate)

    let capture = Capture(text: "Cap 1", subreddits: [sub1])

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [capture])

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows.first?.matchingCaptureCount == 0)
}

@Test @MainActor func refreshSortsWindowsByEventDate() {
    let sub = Subreddit(name: "r/SideProject")

    let later = Date().addingTimeInterval(12 * 3600)
    let sooner = Date().addingTimeInterval(3 * 3600)
    let event1 = SubredditEvent(name: "Later", subreddit: sub, oneOffDate: later)
    let event2 = SubredditEvent(name: "Sooner", subreddit: sub, oneOffDate: sooner)

    let engine = TimingEngine()
    engine.refresh(events: [event1, event2], captures: [])

    #expect(engine.upcomingWindows.count == 2)
    #expect(engine.upcomingWindows[0].event.name == "Sooner")
    #expect(engine.upcomingWindows[1].event.name == "Later")
}
