import Foundation
import Testing
import SwiftData
@testable import RedditReminder

private let edgeCaseNow = Date(timeIntervalSince1970: 1_700_000_000)

@Test func degenerateEventIsNotRecurring() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Empty", subreddit: sub)
    #expect(!event.isRecurring)
    #expect(event.oneOffDate == nil)
}

@Test @MainActor func degenerateEventProducesNoWindow() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Empty", subreddit: sub)

    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window == nil)
}

@Test @MainActor func refreshWithOnlyDegenerateEventsProducesEmpty() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Empty", subreddit: sub)

    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [], now: edgeCaseNow)
    #expect(engine.upcomingWindows.isEmpty)
}

@Test func markAsPostedTwiceUpdatesTimestamp() throws {
    let capture = Capture(text: "Test")
    capture.markAsPosted()
    let firstPostedAt = capture.postedAt!

    Thread.sleep(forTimeInterval: 0.01)
    capture.markAsPosted()

    #expect(capture.status == .posted)
    #expect(capture.postedAt! >= firstPostedAt)
}

@Test func captureCreatedAtIsNearNow() {
    let before = Date()
    let capture = Capture(text: "Test")
    let after = Date()

    #expect(capture.createdAt >= before)
    #expect(capture.createdAt <= after)
}

@Test @MainActor func emptyContainerFetchReturnsEmpty() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    let projects = try context.fetch(FetchDescriptor<Project>())
    let captures = try context.fetch(FetchDescriptor<Capture>())
    let subreddits = try context.fetch(FetchDescriptor<Subreddit>())
    let events = try context.fetch(FetchDescriptor<SubredditEvent>())

    #expect(projects.isEmpty)
    #expect(captures.isEmpty)
    #expect(subreddits.isEmpty)
    #expect(events.isEmpty)
}

@Test func projectDefaultsAreCorrect() {
    let project = Project(name: "Test")
    #expect(project.archived == false)
    #expect(project.captures.isEmpty)
    #expect(project.projectDescription == nil)
    #expect(project.color == nil)
}

@Test func subredditDefaultsAreCorrect() {
    let sub = Subreddit(name: "r/Test")
    #expect(sub.sortOrder == 0)
    #expect(sub.peakDaysOverride == nil)
    #expect(sub.peakHoursUtcOverride == nil)
    #expect(sub.events.isEmpty)
}

@Test func eventDefaultsAreCorrect() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Test", subreddit: sub)
    #expect(event.isActive == true)
    #expect(event.reminderLeadMinutes == 60)
    #expect(event.rrule == nil)
    #expect(event.oneOffDate == nil)
}

@Test func negativeLeadMinutesClampedToZero() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Test", subreddit: sub, reminderLeadMinutes: -30)
    #expect(event.reminderLeadMinutes == 0)
}

@Test func captureDefaultsAreCorrect() {
    let capture = Capture(text: "Test")
    #expect(capture.status == .queued)
    #expect(capture.notes == nil)
    #expect(capture.links.isEmpty)
    #expect(capture.mediaRefs.isEmpty)
    #expect(capture.postedAt == nil)
    #expect(capture.project == nil)
    #expect(capture.subreddits.isEmpty)
}
