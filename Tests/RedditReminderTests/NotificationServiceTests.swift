import Testing
import Foundation
import UserNotifications
@testable import RedditReminder

/// In-memory mock that records all notification operations for verification.
private final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var authorizationResult = true
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var removedAll = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationResult
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

    var mockAuthorizationStatus: UNAuthorizationStatus = .authorized

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        mockAuthorizationStatus
    }
}

// MARK: - Permission

@Test @MainActor func permissionGrantedReturnsTrue() async {
    let mock = MockNotificationCenter()
    mock.authorizationResult = true
    let service = NotificationService(center: mock)
    let result = await service.requestPermission()
    #expect(result == true)
}

@Test @MainActor func permissionDeniedReturnsFalse() async {
    let mock = MockNotificationCenter()
    mock.authorizationResult = false
    let service = NotificationService(center: mock)
    let result = await service.requestPermission()
    #expect(result == false)
}

// MARK: - Scheduling identifiers

@Test @MainActor func windowNotificationUsesCorrectIdentifier() {
    let mock = MockNotificationCenter()
    let service = NotificationService(center: mock)
    let eventId = "550E8400-E29B-41D4-A716-446655440000"

    service.scheduleWindowNotification(
        eventId: eventId,
        subredditName: "r/Swift",
        title: "Post time",
        body: "2 captures ready",
        fireDate: Date().addingTimeInterval(3600)
    )

    #expect(mock.addedRequests.count == 1)
    #expect(mock.addedRequests[0].identifier == AppNotificationIdentifiers.windowRequestId(eventId: eventId))
    #expect(mock.addedRequests[0].content.categoryIdentifier == AppNotificationIdentifiers.postingWindowCategory)
    #expect(mock.addedRequests[0].content.title == "Post time")
    #expect(mock.addedRequests[0].content.body == "2 captures ready")
    #expect(
        mock.addedRequests[0].content.userInfo[AppNotificationIdentifiers.subredditNameUserInfoKey] as? String ==
            "r/Swift"
    )
    #expect(mock.addedRequests[0].content.userInfo[AppNotificationIdentifiers.eventIdUserInfoKey] as? String == eventId)
}

@Test @MainActor func nudgeNotificationUsesCorrectIdentifier() {
    let mock = MockNotificationCenter()
    let service = NotificationService(center: mock)
    let eventId = "AABBCCDD-1234-5678-9ABC-DEF012345678"

    service.scheduleEmptyQueueNudge(
        eventId: eventId,
        subredditName: "r/SideProject",
        eventName: "Show-off Saturday",
        fireDate: Date().addingTimeInterval(7200)
    )

    #expect(mock.addedRequests.count == 1)
    #expect(mock.addedRequests[0].identifier == AppNotificationIdentifiers.nudgeRequestId(eventId: eventId))
    #expect(mock.addedRequests[0].content.categoryIdentifier == AppNotificationIdentifiers.emptyQueueNudgeCategory)
    #expect(mock.addedRequests[0].content.title == "Show-off Saturday is approaching")
    #expect(mock.addedRequests[0].content.body == "Nothing queued for r/SideProject yet — capture something?")
    #expect(
        mock.addedRequests[0].content.userInfo[AppNotificationIdentifiers.subredditNameUserInfoKey] as? String ==
            "r/SideProject"
    )
    #expect(mock.addedRequests[0].content.userInfo[AppNotificationIdentifiers.eventIdUserInfoKey] as? String == eventId)
}

@Test @MainActor func notificationCategoriesUseSharedActionIdentifiers() {
    let categories = NotificationService.categories()
    let windowCategory = categories.first {
        $0.identifier == AppNotificationIdentifiers.postingWindowCategory
    }
    let nudgeCategory = categories.first {
        $0.identifier == AppNotificationIdentifiers.emptyQueueNudgeCategory
    }

    #expect(categories.count == 2)
    #expect(windowCategory?.actions.map(\.identifier) == [
        AppNotificationIdentifiers.openAction,
        AppNotificationIdentifiers.markPostedAction
    ])
    #expect(nudgeCategory?.actions.map(\.identifier) == [AppNotificationIdentifiers.openAction])
}

// MARK: - Cancellation

@Test @MainActor func cancelNotificationsRemovesBothIdentifiers() {
    let mock = MockNotificationCenter()
    let service = NotificationService(center: mock)
    let eventId = "TEST-UUID"

    service.cancelNotifications(eventId: eventId)

    #expect(mock.removedIdentifiers.count == 1)
    #expect(mock.removedIdentifiers[0].contains(AppNotificationIdentifiers.windowRequestId(eventId: eventId)))
    #expect(mock.removedIdentifiers[0].contains(AppNotificationIdentifiers.nudgeRequestId(eventId: eventId)))
}

@Test @MainActor func cancelAllRemovesEverything() {
    let mock = MockNotificationCenter()
    let service = NotificationService(center: mock)

    service.cancelAll()

    #expect(mock.removedAll == true)
}

// MARK: - Permission status check

@Test(arguments: [UNAuthorizationStatus.authorized, .denied, .notDetermined, .provisional])
@MainActor func checkPermissionStatus(expected: UNAuthorizationStatus) async {
    let mock = MockNotificationCenter()
    mock.mockAuthorizationStatus = expected
    let service = NotificationService(center: mock)
    let status = await service.checkPermissionStatus()
    #expect(status == expected)
}

@Test func notificationAuthorizationDisplayLabelsKnownStatuses() {
    #expect(NotificationAuthorizationDisplay.label(for: .authorized) == "Allowed")
    #expect(NotificationAuthorizationDisplay.label(for: .denied) == "Denied")
    #expect(NotificationAuthorizationDisplay.label(for: .notDetermined) == "Not requested")
    #expect(NotificationAuthorizationDisplay.label(for: .provisional) == "Provisional")
}

// MARK: - Trigger correctness

@Test @MainActor func windowNotificationUsesCalendarTrigger() {
    let mock = MockNotificationCenter()
    let service = NotificationService(center: mock)

    let fireDate = Date().addingTimeInterval(3600)
    service.scheduleWindowNotification(
        eventId: "trigger-test",
        subredditName: "r/Test",
        title: "Test",
        body: "Test",
        fireDate: fireDate
    )

    let trigger = mock.addedRequests[0].trigger as? UNCalendarNotificationTrigger
    #expect(trigger != nil)
    #expect(trigger?.repeats == false)

    let cal = Calendar.current
    let expected = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
    #expect(trigger?.dateComponents.year == expected.year)
    #expect(trigger?.dateComponents.month == expected.month)
    #expect(trigger?.dateComponents.day == expected.day)
    #expect(trigger?.dateComponents.hour == expected.hour)
    #expect(trigger?.dateComponents.minute == expected.minute)
}
