import Testing
import Foundation
@testable import RedditReminder

@Test func captureDefaultsToEmptyLinks() {
    let capture = Capture(text: "Hello world")
    #expect(capture.links.isEmpty)
}

@Test func captureWithExplicitLinks() {
    let capture = Capture(
        text: "Check this out",
        links: ["https://github.com/neonwatty/fleet", "https://fleet.app"]
    )
    #expect(capture.links.count == 2)
    #expect(capture.links[0] == "https://github.com/neonwatty/fleet")
    #expect(capture.links[1] == "https://fleet.app")
}

@Test func captureLinkMutation() {
    let capture = Capture(text: "Update")
    capture.links.append("https://example.com")
    #expect(capture.links.count == 1)
    capture.links.remove(at: 0)
    #expect(capture.links.isEmpty)
}

@Test func captureWithLinksAndSubreddits() {
    let sub = Subreddit(name: "r/SwiftUI")
    let capture = Capture(
        text: "New release",
        links: ["https://github.com/neonwatty/reddit-reminder/releases/v2.0"],
        subreddits: [sub]
    )
    #expect(capture.links.count == 1)
    #expect(capture.subreddits.count == 1)
    #expect(capture.status == .queued)
}
