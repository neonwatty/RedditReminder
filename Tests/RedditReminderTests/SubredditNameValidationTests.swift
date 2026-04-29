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
