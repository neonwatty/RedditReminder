import Testing
import Foundation
import UserNotifications
@testable import RedditReminder

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
    UserDefaults.standard.set(true, forKey: SettingsKey.notificationsEnabled)
    UserDefaults.standard.set(true, forKey: SettingsKey.nudgeWhenEmpty)
    defer {
        UserDefaults.standard.removeObject(forKey: SettingsKey.notificationsEnabled)
        UserDefaults.standard.removeObject(forKey: SettingsKey.nudgeWhenEmpty)
    }

    let center = RecordingNotificationCenter()
    let delegate = AppDelegate(
        menuBarController: MenuBarController(),
        timingEngine: TimingEngine(),
        notificationService: NotificationService(center: center),
        heuristicsStore: HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    )
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

    #expect(center.addedRequests.map(\.identifier).contains("window-\(event.id.uuidString)"))
    #expect(center.addedRequests.map(\.identifier).contains("nudge-\(event.id.uuidString)"))
}

@Test @MainActor func appDelegateSkipsPastNotificationFireDatesAndCancelsExistingRequests() async {
    UserDefaults.standard.set(true, forKey: SettingsKey.notificationsEnabled)
    defer { UserDefaults.standard.removeObject(forKey: SettingsKey.notificationsEnabled) }

    let center = RecordingNotificationCenter()
    let delegate = AppDelegate(
        menuBarController: MenuBarController(),
        timingEngine: TimingEngine(),
        notificationService: NotificationService(center: center),
        heuristicsStore: HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    )
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
    #expect(center.removedIdentifiers[0].contains("window-\(event.id.uuidString)"))
    #expect(center.removedIdentifiers[0].contains("nudge-\(event.id.uuidString)"))
}

@Test @MainActor func appDelegateCancelsStaleActiveEvents() async {
    UserDefaults.standard.set(true, forKey: SettingsKey.notificationsEnabled)
    defer { UserDefaults.standard.removeObject(forKey: SettingsKey.notificationsEnabled) }

    let center = RecordingNotificationCenter()
    let delegate = AppDelegate(
        menuBarController: MenuBarController(),
        timingEngine: TimingEngine(),
        notificationService: NotificationService(center: center),
        heuristicsStore: HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    )
    let sub = Subreddit(name: "r/Test")
    let stale = SubredditEvent(name: "Too Far", subreddit: sub, oneOffDate: Date().addingTimeInterval(48 * 3600))

    await delegate.scheduleNotifications(activeEvents: [stale], windows: [])

    #expect(center.removedIdentifiers.count == 1)
    #expect(center.removedIdentifiers[0].contains("window-\(stale.id.uuidString)"))
    #expect(center.removedIdentifiers[0].contains("nudge-\(stale.id.uuidString)"))
}

@Test @MainActor func appDelegateCancelsAllWhenNotificationsDisabled() async {
    UserDefaults.standard.set(false, forKey: SettingsKey.notificationsEnabled)
    defer { UserDefaults.standard.removeObject(forKey: SettingsKey.notificationsEnabled) }

    let center = RecordingNotificationCenter()
    let delegate = AppDelegate(
        menuBarController: MenuBarController(),
        timingEngine: TimingEngine(),
        notificationService: NotificationService(center: center),
        heuristicsStore: HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false)
    )

    await delegate.scheduleNotifications(activeEvents: [], windows: [])

    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}
