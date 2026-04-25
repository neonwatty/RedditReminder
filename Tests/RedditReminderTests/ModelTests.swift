import Testing
import Foundation
@testable import RedditReminder

@Test func projectCreation() {
    let project = Project(name: "Bullhorn")
    #expect(project.name == "Bullhorn")
    #expect(project.archived == false)
    #expect(project.captures.isEmpty)
}

@Test func captureCreation() {
    let project = Project(name: "Bullhorn")
    let sub = Subreddit(name: "r/SideProject")
    let capture = Capture(
        text: "Shipped dark mode",
        project: project,
        subreddits: [sub]
    )
    #expect(capture.text == "Shipped dark mode")
    #expect(capture.status == .queued)
    #expect(capture.subreddits.count == 1)
    #expect(capture.mediaRefs.isEmpty)
    #expect(capture.postedAt == nil)
}

@Test func captureMarkAsPosted() {
    let project = Project(name: "Test")
    let capture = Capture(text: "Update", project: project, subreddits: [])
    capture.markAsPosted()
    #expect(capture.status == .posted)
    #expect(capture.postedAt != nil)
}

@Test func subredditEventRecurring() {
    let sub = Subreddit(name: "r/SideProject")
    let event = SubredditEvent(
        name: "Show-off Saturday",
        subreddit: sub,
        rrule: "FREQ=WEEKLY;BYDAY=SA"
    )
    #expect(event.isRecurring)
    #expect(event.isActive)
}

@Test func subredditEventOneOff() {
    let sub = Subreddit(name: "r/SideProject")
    let event = SubredditEvent(
        name: "Launch Day",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(86400)
    )
    #expect(!event.isRecurring)
}
