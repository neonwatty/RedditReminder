import Testing
@testable import RedditReminder

@Test func eventSourceSummaryCountsOnlyActiveEvents() {
    let subreddit = Subreddit(name: "r/Test")
    let manual = SubredditEvent(name: "Manual", subreddit: subreddit)
    let generated = SubredditEvent(
        name: "Auto",
        subreddit: subreddit,
        isGeneratedFromHeuristics: true,
        generationKey: "r/Test:mon:12"
    )
    let inactiveGenerated = SubredditEvent(
        name: "Inactive",
        subreddit: subreddit,
        isActive: false,
        isGeneratedFromHeuristics: true,
        generationKey: "r/Test:tue:12"
    )

    let summary = EventSourceSummary.active(events: [manual, generated, inactiveGenerated])

    #expect(summary.manualCount == 1)
    #expect(summary.generatedCount == 1)
    #expect(summary.compactLabel == "1 manual · 1 auto")
}

@Test func eventSourceSummaryEmptyLabel() {
    let summary = EventSourceSummary.active(events: [])

    #expect(summary.hasEvents == false)
    #expect(summary.compactLabel == "no events")
}
