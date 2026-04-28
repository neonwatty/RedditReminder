import Foundation
import SwiftData

enum AppModelContainerFactory {
    static var schemaTypes: [any PersistentModel.Type] {
        [Project.self, Capture.self, Subreddit.self, SubredditEvent.self]
    }

    static var schema: Schema {
        Schema(schemaTypes)
    }

    static func makePersistentContainer() throws -> ModelContainer {
        try ModelContainer(for: schema)
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try makePersistentContainer()
        } catch {
            NSLog("RedditReminder: failed to create persistent ModelContainer: \(error)")
            do {
                return try makeInMemoryContainer()
            } catch {
                preconditionFailure("Failed to create fallback ModelContainer: \(error)")
            }
        }
    }
}
