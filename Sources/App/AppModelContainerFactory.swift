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

  static func makePersistentContainer(storeURL: URL? = nil) throws -> ModelContainer {
    if let storeURL {
      let directory = storeURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let configuration = ModelConfiguration("RedditReminderUITests", schema: schema, url: storeURL)
      return try ModelContainer(for: schema, configurations: configuration)
    }

    return try ModelContainer(for: schema)
  }

  static func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: configuration)
  }

  static func makeContainer(storeURL: URL? = nil) throws -> ModelContainer {
    try makeContainer {
      try makePersistentContainer(storeURL: storeURL)
    }
  }

  static func makeContainer(makePersistentContainer: () throws -> ModelContainer) throws
    -> ModelContainer
  {
    do {
      return try makePersistentContainer()
    } catch {
      NSLog("RedditReminder: failed to create persistent ModelContainer: \(error)")
      throw error
    }
  }
}
