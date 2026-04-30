import Testing
import Foundation
import SwiftData
@testable import RedditReminder

@Test @MainActor func markSubredditAsPostedAddsId() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])

    capture.markSubredditAsPosted(sub1.id)

    #expect(capture.postedSubredditIDs.contains(sub1.id))
    #expect(!capture.postedSubredditIDs.contains(sub2.id))
    #expect(capture.status == .queued)
    #expect(capture.postedAt == nil)
}

@Test @MainActor func markAllSubredditsAsPostedTransitionsToPosted() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])

    capture.markSubredditAsPosted(sub1.id)
    capture.markSubredditAsPosted(sub2.id)

    #expect(capture.status == .posted)
    #expect(capture.postedAt != nil)
    #expect(capture.postedSubredditIDs.count == 2)
}

@Test @MainActor func markSubredditAsPostedIdempotent() throws {
    let sub = Subreddit(name: "r/webdev")
    let capture = Capture(text: "Draft", subreddits: [sub])

    capture.markSubredditAsPosted(sub.id)
    capture.markSubredditAsPosted(sub.id)

    #expect(capture.postedSubredditIDs.count == 1)
    #expect(capture.status == .posted)
}

@Test @MainActor func markSubredditAsUnpostedRemovesId() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])
    capture.markSubredditAsPosted(sub1.id)
    capture.markSubredditAsPosted(sub2.id)

    #expect(capture.status == .posted)
    capture.markSubredditAsUnposted(sub1.id)

    #expect(!capture.postedSubredditIDs.contains(sub1.id))
    #expect(capture.postedSubredditIDs.contains(sub2.id))
    #expect(capture.status == .queued)
    #expect(capture.postedAt == nil)
}

@Test @MainActor func markAsPostedFillsAllSubredditIDs() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])

    capture.markAsPosted()

    #expect(capture.postedSubredditIDs.count == 2)
    #expect(capture.postedSubredditIDs.contains(sub1.id))
    #expect(capture.postedSubredditIDs.contains(sub2.id))
}

@Test @MainActor func timingEngineExcludesPartiallyPostedSubreddits() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let event1 = SubredditEvent(name: "E1", subreddit: sub1, oneOffDate: now.addingTimeInterval(3600))
    let event2 = SubredditEvent(name: "E2", subreddit: sub2, oneOffDate: now.addingTimeInterval(3600))

    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])
    capture.markSubredditAsPosted(sub1.id)

    let engine = TimingEngine()
    engine.refresh(events: [event1, event2], captures: [capture], now: now)

    let window1 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub1.id }
    let window2 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub2.id }

    #expect(window1?.matchingCaptureCount == 0)
    #expect(window2?.matchingCaptureCount == 1)
}
