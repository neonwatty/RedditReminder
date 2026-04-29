import Testing
import SwiftData
@testable import RedditReminder

@Test @MainActor func qaFixturesSeedCreatesExpectedData() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)
    let temporaryDefaults = makeTemporaryEdgeCaseDefaults()
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
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)
    let temporaryDefaults = makeTemporaryEdgeCaseDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set("project-id", forKey: SettingsKey.defaultProjectId)

    QAFixtures.clearAll(context: context, defaults: defaults)

    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 0)
    #expect(defaults.object(forKey: SettingsKey.defaultProjectId) == nil)
}
