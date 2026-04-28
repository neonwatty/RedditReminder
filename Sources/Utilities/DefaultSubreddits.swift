import Foundation
import SwiftData

enum DefaultSubreddits {
    static let names = [
        "r/SideProject",
        "r/SwiftUI",
        "r/macOS",
        "r/iOSProgramming",
        "r/programming",
        "r/webdev",
        "r/golang",
        "r/Python",
        "r/MachineLearning",
        "r/learnprogramming",
        "r/devops",
        "r/selfhosted",
    ]

    /// Seeds default subreddits if none exist in the store.
    @MainActor
    static func seedIfEmpty(context: ModelContext) {
        let count: Int
        do {
            count = try context.fetchCount(FetchDescriptor<Subreddit>())
        } catch {
            NSLog("RedditReminder: failed to check subreddit count: \(error)")
            return
        }

        guard count == 0 else { return }

        for (index, name) in names.enumerated() {
            context.insert(Subreddit(name: name, sortOrder: index))
        }

        do {
            try context.save()
            NSLog("RedditReminder: seeded \(names.count) default subreddits")
        } catch {
            context.rollback()
            NSLog("RedditReminder: failed to seed default subreddits: \(error)")
        }
    }
}
