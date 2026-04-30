import Foundation
import SwiftData

enum AppModelContainerFactory {
    static var schemaTypes: [any PersistentModel.Type] {
        [Project.self, Capture.self, Subreddit.self, SubredditEvent.self]
    }

    static var schema: Schema {
        Schema(schemaTypes)
    }

    static var appSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RedditReminder", isDirectory: true)
    }

    static func makePersistentContainer() throws -> ModelContainer {
        try ModelContainer(for: schema)
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func makeContainer() throws -> ModelContainer {
        try makeContainer(makePersistentContainer: makePersistentContainer)
    }

    static func makeContainer(makePersistentContainer: () throws -> ModelContainer) throws -> ModelContainer {
        do {
            return try makePersistentContainer()
        } catch {
            NSLog("RedditReminder: failed to create persistent ModelContainer: \(error)")
            throw error
        }
    }
}
