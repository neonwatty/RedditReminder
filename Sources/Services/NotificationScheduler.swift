import Foundation
@preconcurrency import UserNotifications

@MainActor
struct NotificationScheduler {
    let notificationService: NotificationService
    let defaults: UserDefaults

    init(notificationService: NotificationService, defaults: UserDefaults = .standard) {
        self.notificationService = notificationService
        self.defaults = defaults
    }

    func schedule(
        activeEvents: [SubredditEvent],
        windows: [TimingEngine.UpcomingWindow],
        now: Date = Date()
    ) async -> Int? {
        let notificationsEnabled = defaults.object(forKey: SettingsKey.notificationsEnabled) as? Bool ?? true
        guard notificationsEnabled else {
            notificationService.cancelAll()
            NSLog("RedditReminder: notifications disabled — cancelled all, skipping schedule")
            return nil
        }

        let status = await notificationService.checkPermissionStatus()
        guard status == .authorized else {
            notificationService.cancelAll()
            NSLog("RedditReminder: notification permission not authorized (\(status.rawValue)) — cancelled all, skipping schedule")
            return nil
        }

        var activeEventIds: Set<String> = []
        let nudgeEnabled = defaults.object(forKey: SettingsKey.nudgeWhenEmpty) as? Bool ?? true

        for window in windows {
            let eventId = window.event.id.uuidString
            activeEventIds.insert(eventId)

            guard window.notificationFireDate > now else {
                notificationService.cancelNotifications(eventId: eventId)
                continue
            }

            let subredditName = window.event.subreddit?.name ?? "subreddit"
            notificationService.scheduleWindowNotification(
                eventId: eventId,
                subredditName: subredditName,
                title: window.event.name,
                body: "\(window.matchingCaptureCount) captures ready for \(subredditName)",
                fireDate: window.notificationFireDate
            )

            if window.matchingCaptureCount == 0 && nudgeEnabled {
                notificationService.scheduleEmptyQueueNudge(
                    eventId: eventId,
                    subredditName: subredditName,
                    eventName: window.event.name,
                    fireDate: window.notificationFireDate
                )
            }
        }

        let allEventIds = Set(activeEvents.map { $0.id.uuidString })
        let staleIds = allEventIds.subtracting(activeEventIds)
        for staleId in staleIds {
            notificationService.cancelNotifications(eventId: staleId)
        }

        NSLog("RedditReminder: refresh complete — \(windows.count) windows, \(staleIds.count) cancelled")
        return staleIds.count
    }
}
