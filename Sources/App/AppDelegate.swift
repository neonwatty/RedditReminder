import AppKit
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()
    let timingEngine = TimingEngine()
    let notificationService = NotificationService()
    let heuristicsStore = HeuristicsStore()

    var modelContainer: ModelContainer?

    private let globalShortcut = GlobalShortcut()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global shortcut
        globalShortcut.register { [weak self] in
            self?.menuBarController.togglePopover()
        }

        // Request notification permission
        Task {
            _ = await notificationService.requestPermission()
        }

        // Start 5-minute refresh timer
        startRefreshTimer()

        NSLog("RedditReminder: launched, ⌘⇧R registered, refresh timer started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcut.unregister()
        refreshTimer?.invalidate()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 5 * 60,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.runRefreshCycle()
            }
        }
    }

    func runRefreshCycle() {
        guard let container = modelContainer else {
            NSLog("RedditReminder: refresh skipped — no ModelContainer")
            return
        }

        // Use a fresh context to avoid contention with the view's context,
        // but stay on @MainActor since SwiftData model objects aren't Sendable.
        let context = ModelContext(container)

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
        menuBarController.isUrgent = timingEngine.upcomingWindows.contains { $0.urgency >= .high }
        menuBarController.updateIcon()

        Task {
            await scheduleNotifications(activeEvents: activeEvents, windows: windows)
        }
    }

    private func scheduleNotifications(
        activeEvents: [SubredditEvent],
        windows: [TimingEngine.UpcomingWindow]
    ) async {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
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
        let nudgeEnabled = UserDefaults.standard.object(forKey: "nudgeWhenEmpty") as? Bool ?? true

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
}
