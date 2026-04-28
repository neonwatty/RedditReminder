import Foundation
import SwiftData

@MainActor
enum SubredditPersistenceActions {
    static func isNameAvailable(_ name: String, subreddits: [Subreddit]) -> Bool {
        !subreddits.contains {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    static func canAdd(_ input: String, subreddits: [Subreddit]) -> Bool {
        guard let name = SubredditName.normalizedName(input) else { return false }
        return isNameAvailable(name, subreddits: subreddits)
    }

    @discardableResult
    static func addSubreddit(
        named input: String,
        subreddits: [Subreddit],
        modelContext: ModelContext,
        heuristicsStore: HeuristicsStore,
        defaultLeadTimeMinutes: Int
    ) -> Result<Subreddit, SubredditName.ValidationError> {
        let normalized = SubredditName.normalize(input)
        guard case .success(let name) = normalized else {
            if case .failure(let error) = normalized { return .failure(error) }
            return .failure(.empty)
        }
        guard isNameAvailable(name, subreddits: subreddits) else {
            return .failure(.duplicate)
        }

        let nextOrder = (subreddits.map(\.sortOrder).max() ?? -1) + 1
        let subreddit = Subreddit(name: name, sortOrder: nextOrder)
        modelContext.insert(subreddit)
        do {
            try modelContext.save()
            try heuristicsStore.syncGeneratedEvents(
                for: subreddit,
                context: modelContext,
                defaultLeadTimeMinutes: defaultLeadTimeMinutes
            )
            return .success(subreddit)
        } catch {
            NSLog("RedditReminder: add subreddit failed: \(error)")
            modelContext.delete(subreddit)
            return .failure(.saveFailed)
        }
    }

    @discardableResult
    static func savePendingChanges(
        subreddits: [Subreddit],
        modelContext: ModelContext,
        heuristicsStore: HeuristicsStore,
        defaultLeadTimeMinutes: Int
    ) -> Bool {
        guard modelContext.hasChanges else { return true }
        do {
            try modelContext.save()
            try heuristicsStore.syncGeneratedEvents(
                for: subreddits,
                context: modelContext,
                defaultLeadTimeMinutes: defaultLeadTimeMinutes
            )
            return true
        } catch {
            NSLog("RedditReminder: save pending changes failed: \(error)")
            return false
        }
    }

    @discardableResult
    static func deleteSubreddit(
        _ subreddit: Subreddit,
        modelContext: ModelContext,
        notificationService: NotificationService
    ) -> Bool {
        for event in subreddit.events {
            notificationService.cancelNotifications(eventId: event.id.uuidString)
        }
        modelContext.delete(subreddit)
        do {
            try modelContext.save()
            return true
        } catch {
            NSLog("RedditReminder: delete subreddit failed: \(error)")
            modelContext.rollback()
            return false
        }
    }

    @discardableResult
    static func reorder(
        source: Subreddit,
        target: Subreddit,
        subreddits: [Subreddit],
        modelContext: ModelContext
    ) -> Bool {
        guard source.id != target.id,
              let fromIndex = subreddits.firstIndex(where: { $0.id == source.id }),
              let toIndex = subreddits.firstIndex(where: { $0.id == target.id }) else { return false }

        var reordered = subreddits
        let item = reordered.remove(at: fromIndex)
        reordered.insert(item, at: toIndex)

        for (index, subreddit) in reordered.enumerated() {
            subreddit.sortOrder = index
        }

        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to save subreddit reorder: \(error)")
            return false
        }
    }
}
