import Foundation
import Testing
import SwiftData
@testable import RedditReminder

@Test @MainActor func seedIfEmptyInsertsDefaults() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    DefaultSubreddits.seedIfEmpty(context: context)

    let count = try context.fetchCount(FetchDescriptor<Subreddit>())
    #expect(count == DefaultSubreddits.names.count)
}

@Test @MainActor func seedIfEmptyAssignsStableSortOrder() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    DefaultSubreddits.seedIfEmpty(context: context)

    let descriptor = FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)])
    let subreddits = try context.fetch(descriptor)
    #expect(subreddits.map(\.name) == DefaultSubreddits.names)
    #expect(subreddits.map(\.sortOrder) == Array(DefaultSubreddits.names.indices))
}

@Test @MainActor func seedIfEmptyIsIdempotent() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    DefaultSubreddits.seedIfEmpty(context: context)
    DefaultSubreddits.seedIfEmpty(context: context)

    let count = try context.fetchCount(FetchDescriptor<Subreddit>())
    #expect(count == DefaultSubreddits.names.count)
}

@Test @MainActor func seedIfEmptySkipsWhenDataExists() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    context.insert(Subreddit(name: "r/Existing"))
    try context.save()

    DefaultSubreddits.seedIfEmpty(context: context)

    let count = try context.fetchCount(FetchDescriptor<Subreddit>())
    #expect(count == 1)
}
