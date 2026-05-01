import Testing
import Foundation
import UserNotifications
@testable import RedditReminder

private final class RecordingNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedAll = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationStatus == .authorized
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        handler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func removeAllPendingNotificationRequests() {
        removedAll = true
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }
}

private func makeTestDefaults(
    notificationsEnabled: Bool = true
) -> (UserDefaults, String) {
    let suiteName = "PermissionTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(notificationsEnabled, forKey: SettingsKey.notificationsEnabled)
    return (defaults, suiteName)
}

private func makeTestWindow() -> TimingEngine.UpcomingWindow {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(
        name: "Peak",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(3600),
        reminderLeadMinutes: 0
    )
    return TimingEngine.UpcomingWindow(
        event: event,
        eventDate: event.oneOffDate!,
        notificationFireDate: Date().addingTimeInterval(300),
        urgency: .high,
        matchingCaptureCount: 2
    )
}

@Test @MainActor func permissionDeniedCancelsAllAndReturnsNil() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .denied
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: true)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == nil)
    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}

@Test @MainActor func permissionNotDeterminedCancelsAllAndReturnsNil() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .notDetermined
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: true)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == nil)
    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}

@Test @MainActor func notificationsDisabledInSettingsCancelsAll() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .authorized
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: false)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == nil)
    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}

@Test @MainActor func authorizedAndEnabledSchedulesNotifications() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .authorized
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: true)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == 0)
    #expect(!center.removedAll)
    #expect(center.addedRequests.count == 1)
}
