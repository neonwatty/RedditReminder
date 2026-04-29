import Testing
@testable import RedditReminder

@Test func subredditNameNormalizesBareName() {
    #expect(SubredditName.normalizedName("SideProject") == "r/SideProject")
}

@Test func subredditNameNormalizesPrefixedName() {
    #expect(SubredditName.normalizedName(" r/SwiftUI ") == "r/SwiftUI")
}

@Test func subredditNameNormalizesRedditUrl() {
    #expect(SubredditName.normalizedName("https://www.reddit.com/r/macOS/") == "r/macOS")
}

@Test func subredditNameNormalizesRedditSubdomainUrl() {
    #expect(SubredditName.normalizedName("https://old.reddit.com/r/SwiftUI/comments/abc") == "r/SwiftUI")
}

@Test func subredditNameRejectsNonSubredditRedditUrl() {
    #expect(SubredditName.normalizedName("https://www.reddit.com/user/r/macOS") == nil)
}

@Test func subredditNameRejectsSpaces() {
    #expect(SubredditName.normalize("bad name") == .failure(.invalidCharacters))
}

@Test func subredditNameRejectsNonAsciiLetters() {
    #expect(SubredditName.normalize("café") == .failure(.invalidCharacters))
}

@Test func subredditNameRejectsTooShort() {
    #expect(SubredditName.normalize("ab") == .failure(.tooShort))
}

@Test func subredditNameRejectsTooLong() {
    #expect(SubredditName.normalize(String(repeating: "a", count: 22)) == .failure(.tooLong))
}

@Test @MainActor func subredditInputValidationHasNoFeedbackForEmptyInput() {
    let validation = SubredditInputValidation.evaluate(" ", subreddits: [])

    #expect(validation == SubredditInputValidation(canAdd: false, feedback: nil))
}

@Test @MainActor func subredditInputValidationShowsInvalidNameMessage() {
    let validation = SubredditInputValidation.evaluate("bad name", subreddits: [])

    #expect(validation == SubredditInputValidation(
        canAdd: false,
        feedback: .error(SubredditName.ValidationError.invalidCharacters.message)
    ))
}

@Test @MainActor func subredditInputValidationShowsDuplicateMessage() {
    let existing = Subreddit(name: "r/SwiftUI")
    let validation = SubredditInputValidation.evaluate("swiftui", subreddits: [existing])

    #expect(validation == SubredditInputValidation(
        canAdd: false,
        feedback: .error(SubredditName.ValidationError.duplicate.message)
    ))
}

@Test @MainActor func subredditInputValidationPreviewsNormalizedName() {
    let validation = SubredditInputValidation.evaluate(
        "https://www.reddit.com/r/macOS/comments/abc",
        subreddits: []
    )

    #expect(validation == SubredditInputValidation(
        canAdd: true,
        feedback: .preview("Will add r/macOS")
    ))
}
