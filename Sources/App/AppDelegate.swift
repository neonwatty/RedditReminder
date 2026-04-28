import AppKit
import SwiftData
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let menuBarController = MenuBarController()
    let timingEngine = TimingEngine()
    let notificationService = NotificationService()
    let heuristicsStore = HeuristicsStore()

    var modelContainer: ModelContainer?

    private let globalShortcut = GlobalShortcut()
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global shortcut
        globalShortcut.register { [weak self] in
            MainActor.assumeIsolated {
                self?.menuBarController.togglePopover()
            }
        }

        // Set up notification delegate and categories
        UNUserNotificationCenter.current().delegate = self
        notificationService.registerCategories()

        // Request notification permission
        Task {
            _ = await notificationService.requestPermission()
        }

        // Start 5-minute refresh loop
        startRefreshLoop()

        NSLog("RedditReminder: launched, ⌘⇧R registered, refresh loop started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcut.unregister()
        refreshTask?.cancel()
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { break }
                runRefreshCycle()
            }
        }
    }

    func runRefreshCycle() {
        guard let container = modelContainer else {
            NSLog("RedditReminder: refresh skipped — no ModelContainer")
            return
        }

        let context = container.mainContext

        let events: [SubredditEvent]
        let captures: [Capture]

        do {
            events = try context.fetch(FetchDescriptor<SubredditEvent>())
            captures = try context.fetch(FetchDescriptor<Capture>())
        } catch {
            NSLog("RedditReminder: refresh fetch failed: \(error)")
            return
        }

        let activeEvents = events.filter(\.isActive)
        timingEngine.refresh(events: activeEvents, captures: captures)
        let windows = timingEngine.upcomingWindows

        let queuedCount = captures.filter { $0.status == .queued }.count
        menuBarController.badgeCount = queuedCount
        menuBarController.isUrgent = windows.contains { $0.urgency >= .high }
        menuBarController.updateIcon()

        Task {
            await scheduleNotifications(activeEvents: activeEvents, windows: windows)
        }
    }

    private func scheduleNotifications(
        activeEvents: [SubredditEvent],
        windows: [TimingEngine.UpcomingWindow]
    ) async {
        let notificationsEnabled = UserDefaults.standard.object(forKey: SettingsKey.notificationsEnabled) as? Bool ?? true
        guard notificationsEnabled else {
            notificationService.cancelAll()
            NSLog("RedditReminder: notifications disabled — cancelled all, skipping schedule")
            return
        }

        let status = await notificationService.checkPermissionStatus()
        guard status == .authorized else {
            notificationService.cancelAll()
            NSLog("RedditReminder: notification permission not authorized (\(status.rawValue)) — cancelled all, skipping schedule")
            return
        }

        var activeEventIds: Set<String> = []
        let nudgeEnabled = UserDefaults.standard.object(forKey: SettingsKey.nudgeWhenEmpty) as? Bool ?? true

        let now = Date()
        for window in windows {
            let eventId = window.event.id.uuidString
            activeEventIds.insert(eventId)

            // Skip scheduling if notification fire time is already past
            // (e.g., event in 30 min but lead time is 60 min).
            // A past-dated UNCalendarNotificationTrigger fires immediately.
            guard window.notificationFireDate > now else { continue }

            notificationService.scheduleWindowNotification(
                eventId: eventId,
                subredditName: window.event.subreddit?.name ?? "subreddit",
                title: window.event.name,
                body: "\(window.matchingCaptureCount) captures ready for \(window.event.subreddit?.name ?? "subreddit")",
                fireDate: window.notificationFireDate
            )

            if window.matchingCaptureCount == 0 && nudgeEnabled {
                notificationService.scheduleEmptyQueueNudge(
                    eventId: eventId,
                    subredditName: window.event.subreddit?.name ?? "subreddit",
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
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let subredditName = userInfo["subredditName"] as? String
        let actionId = response.actionIdentifier

        Task { @MainActor in
            switch actionId {
            case "MARK_POSTED_ACTION":
                if let subredditName {
                    self.markCapturesAsPosted(forSubreddit: subredditName)
                }
                self.menuBarController.openPopover()
            case UNNotificationDefaultActionIdentifier, "OPEN_ACTION":
                self.menuBarController.openPopover()
            default:
                break
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func markCapturesAsPosted(forSubreddit name: String) {
        guard let container = modelContainer else {
            NSLog("RedditReminder: markCapturesAsPosted skipped — no ModelContainer")
            return
        }
        let context = container.mainContext
        do {
            let captures = try context.fetch(FetchDescriptor<Capture>())
            let matching = captures.filter { capture in
                capture.status == .queued &&
                capture.subreddits.contains { $0.name == name }
            }
            for capture in matching {
                capture.markAsPosted()
            }
            try context.save()
            NSLog("RedditReminder: marked \(matching.count) captures as posted for \(name)")
        } catch {
            NSLog("RedditReminder: failed to mark captures as posted: \(error)")
        }
    }
}
