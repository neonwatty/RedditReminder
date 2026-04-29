import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import RedditReminder

@Test @MainActor func appDelegateMarksQueuedCapturesForNotificationSubredditAsPosted() throws {
    let container = try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let target = Subreddit(name: "r/Test")
    let other = Subreddit(name: "r/Other")
    let matching = Capture(text: "Matching", subreddits: [target])
    let alreadyPosted = Capture(text: "Posted", subreddits: [target])
    alreadyPosted.markAsPosted()
    let unrelated = Capture(text: "Other", subreddits: [other])
    context.insert(target)
    context.insert(other)
    context.insert(matching)
    context.insert(alreadyPosted)
    context.insert(unrelated)
    try context.save()
    let delegate = makeNotificationActionDelegate()
    delegate.modelContainer = container

    delegate.markCapturesAsPosted(forSubreddit: "r/Test")

    #expect(matching.status == .posted)
    #expect(matching.postedAt != nil)
    #expect(alreadyPosted.status == .posted)
    #expect(unrelated.status == .queued)
}

@Test @MainActor func appDelegateMarkPostedActionIsNoopWithoutContainer() {
    let delegate = makeNotificationActionDelegate()

    delegate.markCapturesAsPosted(forSubreddit: "r/Test")
}

@MainActor
private func makeNotificationActionDelegate() -> AppDelegate {
    AppDelegate(
        menuBarController: MenuBarController(),
        timingEngine: TimingEngine(),
        notificationService: NotificationService(center: NotificationActionCenter()),
        heuristicsStore: HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    )
}

private final class NotificationActionCenter: NotificationCenterProtocol, @unchecked Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {}
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    func removeAllPendingNotificationRequests() {}
    func getAuthorizationStatus() async -> UNAuthorizationStatus { .authorized }
}
