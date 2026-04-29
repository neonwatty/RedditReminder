import Foundation
import SwiftData
@testable import RedditReminder

func makeEdgeCaseContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

struct TemporaryEdgeCaseDefaults {
    let defaults: UserDefaults
    let suiteName: String

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

func makeTemporaryEdgeCaseDefaults() -> TemporaryEdgeCaseDefaults {
    let suiteName = "EdgeCaseTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return TemporaryEdgeCaseDefaults(defaults: defaults, suiteName: suiteName)
}
