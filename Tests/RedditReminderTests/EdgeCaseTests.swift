import Testing
import Foundation
import SwiftData
@testable import RedditReminder

private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

private struct TemporaryDefaults {
    let defaults: UserDefaults
    let suiteName: String

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private func makeTemporaryDefaults() -> TemporaryDefaults {
    let suiteName = "EdgeCaseTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return TemporaryDefaults(defaults: defaults, suiteName: suiteName)
}

// MARK: - DefaultSubreddits seeding

@Test @MainActor func seedIfEmptyInsertsDefaults() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    DefaultSubreddits.seedIfEmpty(context: context)

    let count = try context.fetchCount(FetchDescriptor<Subreddit>())
    #expect(count == DefaultSubreddits.names.count)
}

@Test @MainActor func seedIfEmptyAssignsStableSortOrder() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    DefaultSubreddits.seedIfEmpty(context: context)

    let descriptor = FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)])
    let subreddits = try context.fetch(descriptor)
    #expect(subreddits.map(\.name) == DefaultSubreddits.names)
    #expect(subreddits.map(\.sortOrder) == Array(DefaultSubreddits.names.indices))
}

@Test @MainActor func seedIfEmptyIsIdempotent() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    DefaultSubreddits.seedIfEmpty(context: context)
    DefaultSubreddits.seedIfEmpty(context: context)

    let count = try context.fetchCount(FetchDescriptor<Subreddit>())
    #expect(count == DefaultSubreddits.names.count) // not doubled
}

@Test @MainActor func seedIfEmptySkipsWhenDataExists() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    context.insert(Subreddit(name: "r/Existing"))
    try context.save()

    DefaultSubreddits.seedIfEmpty(context: context)

    let count = try context.fetchCount(FetchDescriptor<Subreddit>())
    #expect(count == 1) // only the manually inserted one
}

// MARK: - Settings options

@Test func leadTimeOptionsAreSharedAndIncludeFifteenMinutes() {
    #expect(SettingsOptions.leadTimeMinutes == [15, 30, 60, 120])
}

// MARK: - Subreddit name validation

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

// MARK: - Degenerate SubredditEvent (no rrule, no oneOffDate)

@Test func degenerateEventIsNotRecurring() {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Empty", subreddit: sub)
    // Neither rrule nor oneOffDate set
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
    engine.refresh(events: [event], captures: [])
    #expect(engine.upcomingWindows.isEmpty)
}

// MARK: - Capture status edge cases

@Test func markAsPostedTwiceUpdatesTimestamp() throws {
    let capture = Capture(text: "Test")
    capture.markAsPosted()
    let firstPostedAt = capture.postedAt!

    // Wait a tiny bit to ensure different timestamp
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

// MARK: - Empty collections

@Test @MainActor func emptyContainerFetchReturnsEmpty() throws {
    let container = try makeContainer()
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

// MARK: - QAFixtures

@Test @MainActor func qaFixturesSeedCreatesExpectedData() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }

    QAFixtures.seed(context: context, defaults: defaults)

    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 4)
    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 3)
    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 8)
    #expect(try context.fetchCount(FetchDescriptor<SubredditEvent>()) == 3)
    #expect(defaults.string(forKey: SettingsKey.defaultProjectId) != nil)
}

@Test @MainActor func qaFixturesClearAllOnEmptyDoesNotCrash() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set("project-id", forKey: SettingsKey.defaultProjectId)

    QAFixtures.clearAll(context: context, defaults: defaults)

    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 0)
    #expect(defaults.object(forKey: SettingsKey.defaultProjectId) == nil)
}

// MARK: - Model defaults

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
