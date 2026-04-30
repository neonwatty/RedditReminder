import Foundation
import Testing

@testable import RedditReminder

private let refreshNow = Date(timeIntervalSince1970: 1_700_000_000)

@Test @MainActor func refreshWithNoEventsProducesEmpty() {
  let engine = TimingEngine()
  engine.refresh(events: [], captures: [], now: refreshNow)
  #expect(engine.upcomingWindows.isEmpty)
}

@Test @MainActor func refreshWithNoCapturesShowsZeroCounts() {
  let sub = Subreddit(name: "r/Test")
  let event = SubredditEvent(
    name: "Soon",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(3600)
  )

  let engine = TimingEngine()
  engine.refresh(events: [event], captures: [], now: refreshNow)

  #expect(engine.upcomingWindows.count == 1)
  #expect(engine.upcomingWindows[0].matchingCaptureCount == 0)
}

@Test @MainActor func refreshExcludesInactiveEvents() {
  let sub = Subreddit(name: "r/Test")
  let active = SubredditEvent(
    name: "Active",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(3600)
  )
  let inactive = SubredditEvent(
    name: "Inactive",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(7200),
    isActive: false
  )

  let engine = TimingEngine()
  engine.refresh(events: [active, inactive], captures: [], now: refreshNow)

  #expect(engine.upcomingWindows.count == 1)
  #expect(engine.upcomingWindows[0].event.name == "Active")
}

@Test @MainActor func refreshExcludesEventsBeyondHorizon() {
  let sub = Subreddit(name: "r/Test")
  let within = SubredditEvent(
    name: "Within",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(12 * 3600)
  )
  let beyond = SubredditEvent(
    name: "Beyond",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(8 * 24 * 3600)
  )

  let engine = TimingEngine()
  engine.refresh(events: [within, beyond], captures: [], now: refreshNow)

  #expect(engine.upcomingWindows.count == 1)
  #expect(engine.upcomingWindows[0].event.name == "Within")
}

@Test @MainActor func refreshExcludesExpiredOneOffEvents() {
  let sub = Subreddit(name: "r/Test")
  let expired = SubredditEvent(
    name: "Expired",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(-3600)
  )

  let engine = TimingEngine()
  engine.refresh(events: [expired], captures: [], now: refreshNow)

  #expect(engine.upcomingWindows.isEmpty)
}

@Test @MainActor func refreshHandlesEventWithNilSubreddit() {
  let sub = Subreddit(name: "r/Test")
  let event = SubredditEvent(
    name: "Orphan",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(3600)
  )
  event.subreddit = nil

  let capture = Capture(text: "Has captures", subreddits: [sub])

  let engine = TimingEngine()
  engine.refresh(events: [event], captures: [capture], now: refreshNow)

  #expect(engine.upcomingWindows.count == 1)
  #expect(engine.upcomingWindows[0].matchingCaptureCount == 0)
}

@Test @MainActor func refreshMixesRecurringAndOneOffEvents() {
  let sub = Subreddit(name: "r/Test")
  let oneOff = SubredditEvent(
    name: "Launch Day",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(6 * 3600)
  )
  let alsoOneOff = SubredditEvent(
    name: "Second Event",
    subreddit: sub,
    oneOffDate: refreshNow.addingTimeInterval(12 * 3600)
  )

  let engine = TimingEngine()
  engine.refresh(events: [oneOff, alsoOneOff], captures: [], now: refreshNow)

  #expect(engine.upcomingWindows.count == 2)
}

@Test @MainActor func refreshCountsMultiSubredditCapture() {
  let sub1 = Subreddit(name: "r/A")
  let sub2 = Subreddit(name: "r/B")
  let event1 = SubredditEvent(
    name: "E1", subreddit: sub1, oneOffDate: refreshNow.addingTimeInterval(3600))
  let event2 = SubredditEvent(
    name: "E2", subreddit: sub2, oneOffDate: refreshNow.addingTimeInterval(7200))

  let capture = Capture(text: "Cross-posted", subreddits: [sub1, sub2])

  let engine = TimingEngine()
  engine.refresh(events: [event1, event2], captures: [capture], now: refreshNow)

  #expect(engine.upcomingWindows.count == 2)
  for window in engine.upcomingWindows {
    #expect(window.matchingCaptureCount == 1)
  }
}

@Test @MainActor func refreshIgnoresPostedCaptures() {
  let sub = Subreddit(name: "r/Test")
  let event = SubredditEvent(
    name: "Post", subreddit: sub, oneOffDate: refreshNow.addingTimeInterval(3600))

  let queued = Capture(text: "Ready", subreddits: [sub])
  let posted = Capture(text: "Done", subreddits: [sub])
  posted.markAsPosted()

  let engine = TimingEngine()
  engine.refresh(events: [event], captures: [queued, posted], now: refreshNow)

  #expect(engine.upcomingWindows[0].matchingCaptureCount == 1)
}
