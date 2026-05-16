import Foundation
import Testing
import SwiftData
@testable import RedditReminder

@Test func qaFixturesExposeLaunchArguments() {
    #expect(QAFixtures.seedLaunchArgument == "--seed-qa")
    #expect(QAFixtures.clearLaunchArgument == "--clear-qa")
}

@Test @MainActor func qaFixturesSeedCreatesExpectedData() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)
    let temporaryDefaults = makeTemporaryEdgeCaseDefaults()
    let defaults = temporaryDefaults.defaults
    let mediaRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let mediaStore = MediaStore(rootDir: mediaRoot)
    defer { temporaryDefaults.cleanup() }
    defer { try? FileManager.default.removeItem(at: mediaRoot) }

    QAFixtures.seed(context: context, defaults: defaults, mediaStore: mediaStore)

    let subreddits = try context.fetch(FetchDescriptor<Subreddit>())
    let captures = try context.fetch(FetchDescriptor<Capture>())
    let events = try context.fetch(FetchDescriptor<SubredditEvent>())

    #expect(subreddits.count == 5)
    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 3)
    #expect(captures.count == 8)
    #expect(events.count == 6)
    #expect(defaults.string(forKey: SettingsKey.defaultProjectId) != nil)
    #expect(subreddits.contains { $0.postingChecklist != nil })
    #expect(captures.contains { !$0.mediaRefs.isEmpty && mediaStore.exists(captureId: $0.id, ref: $0.mediaRefs[0]) })
    #expect(captures.contains { $0.status == .queued && !$0.postedSubredditIDs.isEmpty })
    #expect(events.contains { $0.isGeneratedFromHeuristics })
    #expect(events.contains { $0.isActive == false })
    #expect(
        events.contains {
            $0.name == "No Capture QA Window"
                && $0.subreddit?.name == "r/NoCaptureQA"
        }
    )
    #expect(!captures.contains { $0.subreddits.contains { $0.name == "r/NoCaptureQA" } })
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
