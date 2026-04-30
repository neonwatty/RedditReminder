import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import RedditReminder

private let integrationNow = Date(timeIntervalSince1970: 1_700_000_000)

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

@Test @MainActor func fullLifecycleFromCaptureToPosted() async throws {
    let sub = Subreddit(name: "r/SideProject")
    let eventDate = integrationNow.addingTimeInterval(3 * 3600)
    let event = SubredditEvent(
        name: "Show-off Saturday",
        subreddit: sub,
        oneOffDate: eventDate,
        reminderLeadMinutes: 60
    )
    let capture = Capture(text: "My side project launch", subreddits: [sub])

    // 1. TimingEngine picks up the capture
    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [capture], now: integrationNow)

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows[0].matchingCaptureCount == 1)
    #expect(engine.upcomingWindows[0].urgency == .medium)

    // 2. NotificationScheduler schedules the notification
    let center = RecordingNotificationCenter()
    let service = NotificationService(center: center)
    let suiteName = "LifecycleIntegration-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(true, forKey: SettingsKey.notificationsEnabled)

    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let staleCount = await scheduler.schedule(
        activeEvents: [event],
        windows: engine.upcomingWindows,
        now: integrationNow
    )

    #expect(staleCount == 0)
    #expect(center.addedRequests.count == 1)
    #expect(center.addedRequests[0].content.body == "1 captures ready for r/SideProject")

    // 3. Mark as posted — count drops to 0
    capture.markAsPosted()
    engine.refresh(events: [event], captures: [capture], now: integrationNow)

    #expect(engine.upcomingWindows[0].matchingCaptureCount == 0)
    #expect(capture.status == .posted)
    #expect(capture.postedSubredditIDs.contains(sub.id))
}

@Test @MainActor func perSubredditPostingLifecycle() async throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let sub3 = Subreddit(name: "r/MacApps")

    let eventDate = integrationNow.addingTimeInterval(3 * 3600)
    let event1 = SubredditEvent(name: "E1", subreddit: sub1, oneOffDate: eventDate)
    let event2 = SubredditEvent(name: "E2", subreddit: sub2, oneOffDate: eventDate)
    let event3 = SubredditEvent(name: "E3", subreddit: sub3, oneOffDate: eventDate)

    let capture = Capture(text: "Cross-post draft", subreddits: [sub1, sub2, sub3])

    let engine = TimingEngine()
    engine.refresh(events: [event1, event2, event3], captures: [capture], now: integrationNow)

    // All 3 windows show 1 ready capture
    for window in engine.upcomingWindows {
        #expect(window.matchingCaptureCount == 1)
    }

    // Post to sub1 only
    capture.markSubredditAsPosted(sub1.id)
    #expect(capture.status == .queued)
    engine.refresh(events: [event1, event2, event3], captures: [capture], now: integrationNow)

    let w1 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub1.id }
    let w2 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub2.id }
    let w3 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub3.id }
    #expect(w1?.matchingCaptureCount == 0)
    #expect(w2?.matchingCaptureCount == 1)
    #expect(w3?.matchingCaptureCount == 1)

    // Post to remaining
    capture.markSubredditAsPosted(sub2.id)
    capture.markSubredditAsPosted(sub3.id)
    #expect(capture.status == .posted)

    engine.refresh(events: [event1, event2, event3], captures: [capture], now: integrationNow)
    for window in engine.upcomingWindows {
        #expect(window.matchingCaptureCount == 0)
    }
}
