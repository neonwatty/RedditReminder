import SwiftData
@testable import RedditReminder

/// Creates an in-memory ModelContainer for isolated SwiftData CRUD tests.
func makeCRUDContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}
