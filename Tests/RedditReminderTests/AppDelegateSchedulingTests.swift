import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import RedditReminder

private struct TemporaryDefaults {
    let defaults: UserDefaults
    let suiteName: String

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class RecordingNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var removedAll = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationStatus == .authorized
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        handler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }

    func removeAllPendingNotificationRequests() {
        removedAll = true
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }
}

@Test @MainActor func appDelegateSchedulesWindowAndEmptyQueueNudge() async {
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set(true, forKey: SettingsKey.notificationsEnabled)
    defaults.set(true, forKey: SettingsKey.nudgeWhenEmpty)

    let center = RecordingNotificationCenter()
    let delegate = makeSchedulingDelegate(center: center, defaults: defaults)
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Peak", subreddit: sub, oneOffDate: Date().addingTimeInterval(3600))
    let window = TimingEngine.UpcomingWindow(
        event: event,
        eventDate: event.oneOffDate!,
        notificationFireDate: Date().addingTimeInterval(300),
        urgency: .high,
        matchingCaptureCount: 0
    )

    await delegate.scheduleNotifications(activeEvents: [event], windows: [window])

    #expect(center.addedRequests.map(\.identifier).contains(AppNotificationIdentifiers.windowRequestId(eventId: event.id.uuidString)))
    #expect(center.addedRequests.map(\.identifier).contains(AppNotificationIdentifiers.nudgeRequestId(eventId: event.id.uuidString)))
}

@Test @MainActor func appDelegateSkipsPastNotificationFireDatesAndCancelsExistingRequests() async {
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set(true, forKey: SettingsKey.notificationsEnabled)

    let center = RecordingNotificationCenter()
    let delegate = makeSchedulingDelegate(center: center, defaults: defaults)
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(name: "Peak", subreddit: sub, oneOffDate: Date().addingTimeInterval(1800))
    let window = TimingEngine.UpcomingWindow(
        event: event,
        eventDate: event.oneOffDate!,
        notificationFireDate: Date().addingTimeInterval(-60),
        urgency: .active,
        matchingCaptureCount: 1
    )

    await delegate.scheduleNotifications(activeEvents: [event], windows: [window])

    #expect(center.addedRequests.isEmpty)
    #expect(center.removedIdentifiers.count == 1)
    #expect(center.removedIdentifiers[0].contains(AppNotificationIdentifiers.windowRequestId(eventId: event.id.uuidString)))
    #expect(center.removedIdentifiers[0].contains(AppNotificationIdentifiers.nudgeRequestId(eventId: event.id.uuidString)))
}

@Test @MainActor func appDelegateCancelsStaleActiveEvents() async {
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set(true, forKey: SettingsKey.notificationsEnabled)

    let center = RecordingNotificationCenter()
    let delegate = makeSchedulingDelegate(center: center, defaults: defaults)
    let sub = Subreddit(name: "r/Test")
    let stale = SubredditEvent(name: "Too Far", subreddit: sub, oneOffDate: Date().addingTimeInterval(48 * 3600))

    await delegate.scheduleNotifications(activeEvents: [stale], windows: [])

    #expect(center.removedIdentifiers.count == 1)
    #expect(center.removedIdentifiers[0].contains(AppNotificationIdentifiers.windowRequestId(eventId: stale.id.uuidString)))
    #expect(center.removedIdentifiers[0].contains(AppNotificationIdentifiers.nudgeRequestId(eventId: stale.id.uuidString)))
}

@Test @MainActor func appDelegateCancelsAllWhenNotificationsDisabled() async {
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set(false, forKey: SettingsKey.notificationsEnabled)

    let center = RecordingNotificationCenter()
    let delegate = makeSchedulingDelegate(center: center, defaults: defaults)

    await delegate.scheduleNotifications(activeEvents: [], windows: [])

    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}

@Test @MainActor func appDelegateCancelsAllWhenNotificationPermissionDenied() async {
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set(true, forKey: SettingsKey.notificationsEnabled)

    let center = RecordingNotificationCenter()
    center.authorizationStatus = .denied
    let delegate = makeSchedulingDelegate(center: center, defaults: defaults)
    let event = SubredditEvent(
        name: "Peak",
        subreddit: Subreddit(name: "r/Test"),
        oneOffDate: Date().addingTimeInterval(3600)
    )
    let window = TimingEngine.UpcomingWindow(
        event: event,
        eventDate: event.oneOffDate!,
        notificationFireDate: Date().addingTimeInterval(300),
        urgency: .high,
        matchingCaptureCount: 1
    )

    await delegate.scheduleNotifications(activeEvents: [event], windows: [window])

    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
    #expect(center.removedIdentifiers.isEmpty)
}

@Test @MainActor func appDelegateUsesInjectedDefaultLeadTimeWhenSyncingEvents() throws {
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set(15, forKey: SettingsKey.defaultLeadTimeMinutes)
    defaults.set(false, forKey: SettingsKey.notificationsEnabled)

    let container = try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let subreddit = Subreddit(name: "r/SideProject")
    context.insert(subreddit)
    try context.save()

    let center = RecordingNotificationCenter()
    let store = HeuristicsStore(bundle: makeHeuristicsTestBundle(), logsMissingResource: false)
    let delegate = makeSchedulingDelegate(center: center, defaults: defaults, heuristicsStore: store)
    delegate.modelContainer = container

    delegate.runRefreshCycle()

    let events = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(!events.isEmpty)
    #expect(events.allSatisfy { $0.reminderLeadMinutes == 15 })
}

@Test @MainActor func appDelegateCoreWorkflowRefreshesBadgeAndNotificationsAfterMarkPosted() async throws {
    let temporaryDefaults = makeTemporaryDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    defaults.set(true, forKey: SettingsKey.notificationsEnabled)
    defaults.set(true, forKey: SettingsKey.nudgeWhenEmpty)

    let container = try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let subreddit = Subreddit(name: "r/Test")
    let event = SubredditEvent(
        name: "Soon",
        subreddit: subreddit,
        oneOffDate: Date().addingTimeInterval(3600),
        reminderLeadMinutes: 0
    )
    let capture = Capture(text: "Draft", subreddits: [subreddit])
    context.insert(subreddit)
    context.insert(event)
    context.insert(capture)
    try context.save()

    let center = RecordingNotificationCenter()
    let delegate = makeSchedulingDelegate(center: center, defaults: defaults)
    delegate.modelContainer = container

    delegate.runRefreshCycle()
    await waitForNotificationRequests(in: center, count: 1)

    #expect(delegate.menuBarController.badgeCount == 1)
    #expect(delegate.menuBarController.isUrgent)
    #expect(center.addedRequests.count == 1)
    #expect(center.addedRequests.last?.content.body == "1 captures ready for r/Test")

    delegate.handleNotificationAction(AppNotificationIdentifiers.markPostedAction, subredditName: "r/Test")
    await waitForNotificationRequests(in: center, count: 3)

    #expect(capture.status == .posted)
    #expect(delegate.menuBarController.badgeCount == 0)
    #expect(delegate.menuBarController.isUrgent)
    #expect(center.addedRequests.suffix(2).map(\.identifier).contains(
        AppNotificationIdentifiers.windowRequestId(eventId: event.id.uuidString)
    ))
    #expect(center.addedRequests.suffix(2).map(\.identifier).contains(
        AppNotificationIdentifiers.nudgeRequestId(eventId: event.id.uuidString)
    ))
    #expect(center.addedRequests.suffix(2).contains { $0.content.body == "0 captures ready for r/Test" })
}

@MainActor
private func makeSchedulingDelegate(
    center: RecordingNotificationCenter,
    defaults: UserDefaults,
    heuristicsStore: HeuristicsStore = HeuristicsStore(
        bundle: Bundle(path: "/tmp") ?? .main,
        logsMissingResource: false
    )
) -> AppDelegate {
    AppDelegate(
        menuBarController: MenuBarController(),
        timingEngine: TimingEngine(),
        notificationService: NotificationService(center: center),
        heuristicsStore: heuristicsStore,
        defaults: defaults
    )
}

private func makeTemporaryDefaults() -> TemporaryDefaults {
    let suiteName = "AppDelegateSchedulingTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return TemporaryDefaults(defaults: defaults, suiteName: suiteName)
}

private func waitForNotificationRequests(
    in center: RecordingNotificationCenter,
    count: Int
) async {
    for _ in 0..<50 {
        if center.addedRequests.count >= count { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
}

private func makeHeuristicsTestBundle() -> Bundle {
    let sourceFile = URL(fileURLWithPath: #filePath)
    let projectRoot = sourceFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let resourcesDir = projectRoot.appendingPathComponent("Resources")
    return Bundle(path: resourcesDir.path) ?? .main
}
