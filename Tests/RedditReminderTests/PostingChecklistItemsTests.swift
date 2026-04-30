import Testing
@testable import RedditReminder

@Test func postingChecklistItemsRemoveBlankLinesAndTrimWhitespace() {
    let checklist = """

      Confirm title formatting

    Attach launch screenshot
        
    Review subreddit rules
    """

    #expect(PostingChecklistItems.cleaned(from: checklist) == [
        "Confirm title formatting",
        "Attach launch screenshot",
        "Review subreddit rules",
    ])
}

@Test func postingChecklistItemsEmptyInputReturnsEmptyList() {
    #expect(PostingChecklistItems.cleaned(from: nil).isEmpty)
    #expect(PostingChecklistItems.cleaned(from: "").isEmpty)
    #expect(PostingChecklistItems.cleaned(from: ["", "   ", "\t"]).isEmpty)
}
