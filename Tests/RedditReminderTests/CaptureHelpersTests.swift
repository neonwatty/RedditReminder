import Testing
import Foundation
import SwiftData
@testable import RedditReminder

// MARK: - normalizeLink

@Test func normalizeLinkPrependsHttps() {
    #expect(CaptureHelpers.normalizeLink("example.com") == "https://example.com")
}

@Test func normalizeLinkKeepsHttps() {
    #expect(CaptureHelpers.normalizeLink("https://example.com") == "https://example.com")
}

@Test func normalizeLinkKeepsHttp() {
    #expect(CaptureHelpers.normalizeLink("http://example.com") == "http://example.com")
}

@Test func normalizeLinkTrimsWhitespace() {
    #expect(CaptureHelpers.normalizeLink("  https://example.com  ") == "https://example.com")
}

@Test func normalizeLinkRejectsEmpty() {
    #expect(CaptureHelpers.normalizeLink("") == nil)
}

@Test func normalizeLinkRejectsWhitespaceOnly() {
    #expect(CaptureHelpers.normalizeLink("   ") == nil)
}

@Test func normalizeLinkBareDomain() {
    #expect(CaptureHelpers.normalizeLink("reddit.com/r/SwiftUI") == "https://reddit.com/r/SwiftUI")
}

@Test func normalizeLinkRejectsUnsupportedSchemes() {
    #expect(CaptureHelpers.normalizeLink("ftp://example.com/file.zip") == nil)
    #expect(CaptureHelpers.normalizeLink("mailto:test@example.com") == nil)
}

@Test func normalizeLinkRejectsInternalWhitespace() {
    #expect(CaptureHelpers.normalizeLink("https://example.com/bad path") == nil)
    #expect(CaptureHelpers.normalizeLink("bad domain.com") == nil)
}

@Test func normalizeLinkRejectsMissingHost() {
    #expect(CaptureHelpers.normalizeLink("https://") == nil)
}

// MARK: - canSave

@Test func canSaveRequiresNonEmptyTextAndSubreddits() {
    #expect(CaptureHelpers.canSave(text: "Hello", selectedSubredditCount: 1) == true)
}

@Test func canSaveRejectsEmptyText() {
    #expect(CaptureHelpers.canSave(text: "", selectedSubredditCount: 1) == false)
}

@Test func canSaveRejectsWhitespaceOnlyText() {
    #expect(CaptureHelpers.canSave(text: "   \n  ", selectedSubredditCount: 1) == false)
}

@Test func canSaveRejectsZeroSubreddits() {
    #expect(CaptureHelpers.canSave(text: "Hello", selectedSubredditCount: 0) == false)
}

@Test func canSaveRejectsBothEmpty() {
    #expect(CaptureHelpers.canSave(text: "", selectedSubredditCount: 0) == false)
}

// MARK: - search

@Test func captureSearchMatchesText() {
    let capture = Capture(text: "Launch notes")
    #expect(CaptureHelpers.matchesSearch(capture, query: "launch"))
}

@Test func captureSearchMatchesRelatedFields() {
    let sub = Subreddit(name: "r/SwiftUI")
    let project = Project(name: "ReminderApp", projectDescription: "Menu bar workflow")
    let capture = Capture(
        text: "Post copy",
        notes: "Include screenshot",
        links: ["https://example.com/demo"],
        mediaRefs: ["hero.png"],
        project: project,
        subreddits: [sub]
    )

    #expect(CaptureHelpers.matchesSearch(capture, query: "swiftui"))
    #expect(CaptureHelpers.matchesSearch(capture, query: "screenshot"))
    #expect(CaptureHelpers.matchesSearch(capture, query: "demo"))
    #expect(CaptureHelpers.matchesSearch(capture, query: "hero"))
    #expect(CaptureHelpers.matchesSearch(capture, query: "menu bar"))
}

@Test func captureSearchRejectsNoMatch() {
    let capture = Capture(text: "Launch notes")
    #expect(!CaptureHelpers.matchesSearch(capture, query: "calendar"))
}

// MARK: - renderMarkdown

@Test func renderMarkdownBoldText() {
    let result = CaptureHelpers.renderMarkdown("**bold**")
    #expect(result != nil)
}

@Test func renderMarkdownItalicText() {
    let result = CaptureHelpers.renderMarkdown("*italic*")
    #expect(result != nil)
}

@Test func renderMarkdownStripsStrikethrough() {
    let result = CaptureHelpers.renderMarkdown("~~removed~~ kept")
    #expect(result != nil)
    // Strikethrough markers should be stripped, leaving "removed kept"
    let plain = result.map { String($0.characters) }
    #expect(plain == "removed kept")
}

@Test func renderMarkdownPlainText() {
    let result = CaptureHelpers.renderMarkdown("just plain text")
    #expect(result != nil)
    let plain = result.map { String($0.characters) }
    #expect(plain == "just plain text")
}

@Test func renderMarkdownEmptyString() {
    let result = CaptureHelpers.renderMarkdown("")
    #expect(result != nil)
}

@Test func renderMarkdownInlineLink() {
    let result = CaptureHelpers.renderMarkdown("[click](https://example.com)")
    #expect(result != nil)
}

// MARK: - markCapturesAsPosted (SwiftData integration)

private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Capture.self, Subreddit.self, SubredditEvent.self, Project.self,
        configurations: config
    )
}

@Test @MainActor func markCapturesAsPostedFiltersCorrectly() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let swift = Subreddit(name: "r/Swift", sortOrder: 0)
    let ios = Subreddit(name: "r/iOS", sortOrder: 1)
    context.insert(swift)
    context.insert(ios)

    let c1 = Capture(text: "Post 1", subreddits: [swift])
    let c2 = Capture(text: "Post 2", subreddits: [swift])
    let c3 = Capture(text: "Post 3", subreddits: [ios])
    let c4 = Capture(text: "Already posted", subreddits: [swift])
    c4.markAsPosted()
    context.insert(c1)
    context.insert(c2)
    context.insert(c3)
    context.insert(c4)
    try context.save()

    // Simulate what AppDelegate.markCapturesAsPosted does
    let allCaptures = try context.fetch(FetchDescriptor<Capture>())
    let matching = allCaptures.filter { capture in
        capture.status == .queued &&
        capture.subreddits.contains { $0.name == "r/Swift" }
    }
    for capture in matching {
        capture.markAsPosted()
    }
    try context.save()

    // c1 and c2 should now be posted
    #expect(c1.status == .posted)
    #expect(c1.postedAt != nil)
    #expect(c2.status == .posted)
    #expect(c2.postedAt != nil)

    // c3 (different subreddit) should still be queued
    #expect(c3.status == .queued)
    #expect(c3.postedAt == nil)

    // c4 (already posted) should still be posted
    #expect(c4.status == .posted)
}

@Test @MainActor func markCapturesAsPostedNoMatchIsNoop() throws {
    let container = try makeContainer()
    let context = container.mainContext

    let sub = Subreddit(name: "r/Swift", sortOrder: 0)
    context.insert(sub)

    let c1 = Capture(text: "Post 1", subreddits: [sub])
    context.insert(c1)
    try context.save()

    let allCaptures = try context.fetch(FetchDescriptor<Capture>())
    let matching = allCaptures.filter { capture in
        capture.status == .queued &&
        capture.subreddits.contains { $0.name == "r/NoMatch" }
    }
    #expect(matching.isEmpty)

    // c1 should still be queued
    #expect(c1.status == .queued)
}
