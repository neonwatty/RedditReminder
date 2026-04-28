import Testing
@testable import RedditReminder

@Test func popoverFilteringSeparatesQueuedAndPostedCaptures() {
    let queued = Capture(text: "Queued")
    let posted = Capture(text: "Posted")
    posted.markAsPosted()

    #expect(PopoverCaptureFiltering.queuedCaptures(from: [queued, posted]).map(\.id) == [queued.id])
    #expect(PopoverCaptureFiltering.postedCaptures(from: [queued, posted]).map(\.id) == [posted.id])
}

@Test func popoverFilteringAppliesSubredditFilterOnlyToQueuedCaptures() {
    let swift = Subreddit(name: "r/Swift")
    let mac = Subreddit(name: "r/macOS")
    let matching = Capture(text: "Swift post", subreddits: [swift])
    let other = Capture(text: "Mac post", subreddits: [mac])
    let posted = Capture(text: "Posted Swift", subreddits: [swift])
    posted.markAsPosted()

    let displayed = PopoverCaptureFiltering.displayedQueuedCaptures(
        from: [matching, other, posted],
        filterSubredditId: swift.id,
        searchText: ""
    )

    #expect(displayed.map(\.id) == [matching.id])
}

@Test func popoverFilteringSearchesQueuedAndPostedCaptures() {
    let queuedMatch = Capture(text: "Launch notes")
    let queuedOther = Capture(text: "Roadmap")
    let postedMatch = Capture(text: "Launch recap")
    postedMatch.markAsPosted()

    let queued = PopoverCaptureFiltering.displayedQueuedCaptures(
        from: [queuedMatch, queuedOther, postedMatch],
        filterSubredditId: nil,
        searchText: "launch"
    )
    let posted = PopoverCaptureFiltering.displayedPostedCaptures(
        from: [queuedMatch, queuedOther, postedMatch],
        searchText: "launch"
    )

    #expect(queued.map(\.id) == [queuedMatch.id])
    #expect(posted.map(\.id) == [postedMatch.id])
}
