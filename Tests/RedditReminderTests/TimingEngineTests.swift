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
