import Foundation
import SwiftData
import Testing

@testable import RedditReminder

@Test func appModelContainerFactoryDefinesExpectedSchemaTypes() {
  let names = AppModelContainerFactory.schemaTypes.map { String(describing: $0) }

  #expect(names == ["Project", "Capture", "Subreddit", "SubredditEvent"])
}

@Test @MainActor func appModelContainerFactoryCreatesInMemoryContainer() throws {
  let container = try AppModelContainerFactory.makeInMemoryContainer()
  let context = ModelContext(container)
  context.insert(Project(name: "Smoke"))
  try context.save()

  let projects = try context.fetch(FetchDescriptor<Project>())
  #expect(projects.map(\.name) == ["Smoke"])
}

@Test @MainActor func appModelContainerFactoryCreatesContainerAtExplicitStoreURL() throws {
  let storeURL = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
    .appendingPathComponent("RedditReminderUITests.store")
  defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

  let container = try AppModelContainerFactory.makePersistentContainer(storeURL: storeURL)
  let context = ModelContext(container)
  context.insert(Project(name: "Isolated"))
  try context.save()

  #expect(FileManager.default.fileExists(atPath: storeURL.path))
  #expect(!storeURL.path.contains(AppModelContainerFactory.appSupportDirectory.path))
}

@Test @MainActor func appModelContainerFactoryPropagatesPersistentStoreFailure() throws {
  enum StoreFailure: Error, Equatable {
    case unavailable
  }

  #expect(throws: StoreFailure.unavailable) {
    _ = try AppModelContainerFactory.makeContainer {
      throw StoreFailure.unavailable
    }
  }
}

@Test func appModelContainerFactoryExposesAppSupportDirectory() {
  let directory = AppModelContainerFactory.appSupportDirectory

  #expect(directory.lastPathComponent == "RedditReminder")
  #expect(directory.path.contains("Application Support"))
}
