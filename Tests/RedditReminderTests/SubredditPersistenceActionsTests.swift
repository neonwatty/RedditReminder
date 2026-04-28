import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import RedditReminder

private final class RecordingSubredditNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    private(set) var removedIdentifiers: [[String]] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {}
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }
    func removeAllPendingNotificationRequests() {}
    func getAuthorizationStatus() async -> UNAuthorizationStatus { .authorized }
}

private func makeSubredditActionsContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

@Test @MainActor func subredditCanAddRejectsInvalidAndDuplicateNames() {
    let existing = Subreddit(name: "r/SwiftUI")

    #expect(!SubredditPersistenceActions.canAdd("bad name", subreddits: [existing]))
    #expect(!SubredditPersistenceActions.canAdd("swiftui", subreddits: [existing]))
    #expect(SubredditPersistenceActions.canAdd("macOS", subreddits: [existing]))
}

@Test @MainActor func addSubredditPersistsNormalizedNameAndSortOrder() throws {
    let container = try makeSubredditActionsContainer()
    let context = ModelContext(container)
    let existing = Subreddit(name: "r/Existing", sortOrder: 4)
    context.insert(existing)
    try context.save()

    let store = HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    let result = SubredditPersistenceActions.addSubreddit(
        named: "  TestSub  ",
        subreddits: [existing],
        modelContext: context,
        heuristicsStore: store,
        defaultLeadTimeMinutes: 30
    )

    guard case .success(let subreddit) = result else {
        Issue.record("Expected subreddit to be added")
        return
    }
    #expect(subreddit.name == "r/TestSub")
    #expect(subreddit.sortOrder == 5)
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 2)
}

@Test @MainActor func addSubredditRejectsDuplicateName() throws {
    let container = try makeSubredditActionsContainer()
    let context = ModelContext(container)
    let existing = Subreddit(name: "r/SwiftUI")
    context.insert(existing)
    try context.save()

    let store = HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    let result = SubredditPersistenceActions.addSubreddit(
        named: "swiftui",
        subreddits: [existing],
        modelContext: context,
        heuristicsStore: store,
        defaultLeadTimeMinutes: 60
    )

    #expect(result == .failure(.duplicate))
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 1)
}

@Test @MainActor func addSubredditSyncsGeneratedPeakEvents() throws {
    let container = try makeSubredditActionsContainer()
    let context = ModelContext(container)
    let store = HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    store.setOverride(for: "r/TestSub", peakDays: ["mon"], peakHoursUtc: [14, 15])

    let result = SubredditPersistenceActions.addSubreddit(
        named: "TestSub",
        subreddits: [],
        modelContext: context,
        heuristicsStore: store,
        defaultLeadTimeMinutes: 45
    )

    guard case .success(let subreddit) = result else {
        Issue.record("Expected subreddit to be added")
        return
    }

    let events = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(events.count == 2)
    #expect(events.allSatisfy { $0.isGeneratedFromHeuristics })
    #expect(events.allSatisfy { $0.subreddit?.id == subreddit.id })
    #expect(Set(events.compactMap(\.recurrenceHour)) == [14, 15])
    #expect(events.allSatisfy { $0.reminderLeadMinutes == 45 })
}

@Test @MainActor func savePendingChangesPersistsPeakOverrideAndResyncsGeneratedEvents() throws {
    let container = try makeSubredditActionsContainer()
    let context = ModelContext(container)
    let subreddit = Subreddit(name: "r/TestSub")
    context.insert(subreddit)
    try context.save()

    let store = HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    subreddit.peakDaysOverride = ["tue"]
    subreddit.peakHoursUtcOverride = [9]

    let ok = SubredditPersistenceActions.savePendingChanges(
        subreddits: [subreddit],
        modelContext: context,
        heuristicsStore: store,
        defaultLeadTimeMinutes: 20
    )

    let events = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(ok)
    #expect(events.count == 1)
    #expect(events[0].rrule == "FREQ=WEEKLY;BYDAY=TU")
    #expect(events[0].recurrenceHour == 9)
    #expect(events[0].reminderLeadMinutes == 20)
}

@Test @MainActor func deleteSubredditCancelsEventNotificationsAndDeletesEvents() throws {
    let container = try makeSubredditActionsContainer()
    let context = ModelContext(container)
    let center = RecordingSubredditNotificationCenter()
    let service = NotificationService(center: center)
    let subreddit = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Peak", subreddit: subreddit, oneOffDate: Date().addingTimeInterval(3600))
    context.insert(subreddit)
    context.insert(event)
    try context.save()
    let eventId = event.id.uuidString

    let ok = SubredditPersistenceActions.deleteSubreddit(
        subreddit,
        modelContext: context,
        notificationService: service
    )

    #expect(ok)
    #expect(center.removedIdentifiers.count == 1)
    #expect(center.removedIdentifiers[0].contains("window-\(eventId)"))
    #expect(center.removedIdentifiers[0].contains("nudge-\(eventId)"))
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<SubredditEvent>()) == 0)
}

@Test @MainActor func reorderSubredditsPersistsSequentialSortOrder() throws {
    let container = try makeSubredditActionsContainer()
    let context = ModelContext(container)
    let first = Subreddit(name: "r/A", sortOrder: 0)
    let second = Subreddit(name: "r/B", sortOrder: 1)
    let third = Subreddit(name: "r/C", sortOrder: 2)
    for subreddit in [first, second, third] {
        context.insert(subreddit)
    }
    try context.save()

    let ok = SubredditPersistenceActions.reorder(
        source: third,
        target: first,
        subreddits: [first, second, third],
        modelContext: context
    )

    #expect(ok)
    #expect(third.sortOrder == 0)
    #expect(first.sortOrder == 1)
    #expect(second.sortOrder == 2)
}
