import Testing
import Foundation
@testable import RedditReminder

@Test @MainActor func crossTimezoneResolution() {
    let sub = Subreddit(name: "r/webdev")
    let event = SubredditEvent(
        name: "Morning Post",
        subreddit: sub,
        rrule: "FREQ=WEEKLY;BYDAY=MO",
        recurrenceHour: 10,
        recurrenceMinute: 0,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )

    // Use a UTC time: Sunday 2023-11-12 20:00 UTC = Sunday 3:00 PM ET
    // Next Monday 10:00 AM ET = Monday 2023-11-13 15:00 UTC
    let utcCal = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = utcCal.date(from: DateComponents(year: 2023, month: 11, day: 12, hour: 20, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)

    // Verify the window is on Monday in ET
    var etCal = Calendar(identifier: .gregorian)
    etCal.timeZone = TimeZone(identifier: "America/New_York")!
    let components = etCal.dateComponents([.weekday, .hour, .minute], from: window!)
    #expect(components.weekday == 2)  // Monday
    #expect(components.hour == 10)
    #expect(components.minute == 0)
}

@Test @MainActor func dayBoundaryTimezone() {
    let sub = Subreddit(name: "r/japan")
    let event = SubredditEvent(
        name: "Daily",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 1,
        recurrenceMinute: 0,
        recurrenceTimeZoneIdentifier: "Asia/Tokyo"
    )

    // 11:00 PM UTC = 8:00 AM JST next day. 1:00 AM JST has passed.
    // Next occurrence should be 1:00 AM JST the day AFTER the JST day.
    let utcCal = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = utcCal.date(from: DateComponents(year: 2023, month: 11, day: 15, hour: 23, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)
    #expect(window! > now)

    var jstCal = Calendar(identifier: .gregorian)
    jstCal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    let components = jstCal.dateComponents([.hour, .minute], from: window!)
    #expect(components.hour == 1)
    #expect(components.minute == 0)
}

@Test @MainActor func dstSpringForwardProducesValidDate() {
    let sub = Subreddit(name: "r/test")
    // 2:30 AM ET doesn't exist during spring forward (2024-03-10 in US)
    let event = SubredditEvent(
        name: "Early",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 2,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )

    var etCal = Calendar(identifier: .gregorian)
    etCal.timeZone = TimeZone(identifier: "America/New_York")!
    // March 9, 2024 11:00 PM ET — just before spring forward
    let now = etCal.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 23, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    // Should still produce a valid date (not nil, not crash)
    #expect(window != nil)
    #expect(window! > now)
}

@Test @MainActor func dstFallBackDoesNotDoubleCount() {
    let sub = Subreddit(name: "r/test")
    // 1:30 AM ET is ambiguous during fall back (2024-11-03 in US)
    let event = SubredditEvent(
        name: "Ambiguous",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 1,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )

    var etCal = Calendar(identifier: .gregorian)
    etCal.timeZone = TimeZone(identifier: "America/New_York")!
    // Nov 3, 2024 12:00 AM ET — before the ambiguous hour
    let now = etCal.date(from: DateComponents(year: 2024, month: 11, day: 3, hour: 0, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)
    #expect(window! > now)

    // Should produce exactly one occurrence, not two
    let engine = TimingEngine()
    let windowEvent = SubredditEvent(
        name: "Ambiguous",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 1,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )
    let capture = Capture(text: "Test", subreddits: [sub])
    engine.refresh(events: [windowEvent], captures: [capture], now: now, horizonDays: 1)
    #expect(engine.upcomingWindows.count == 1)
}
