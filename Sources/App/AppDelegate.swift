import AppKit
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelController = PanelController()
    let timingEngine = TimingEngine()
    let notificationService = NotificationService()
    let heuristicsStore = HeuristicsStore()

    var modelContainer: ModelContainer?

    private let globalShortcut = GlobalShortcut()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global shortcut
        globalShortcut.register { [weak self] in
            self?.panelController.toggleCapture()
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
        Task {
            await scheduleNotifications(activeEvents: activeEvents)
        }
    }

    private func scheduleNotifications(activeEvents: [SubredditEvent]) async {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard notificationsEnabled else {
            notificationService.cancelAll()
            NSLog("RedditReminder: notifications disabled — cancelled all, skipping schedule")
            return
        }

        let status = await notificationService.checkPermissionStatus()
        guard status == .authorized else {
            // Still clean up stale notifications even when not authorized,
            // so previously-scheduled notifications don't linger.
            let allEventIds = Set(activeEvents.map { $0.id.uuidString })
            let windowEventIds = Set(timingEngine.upcomingWindows.map { $0.event.id.uuidString })
            for staleId in allEventIds.subtracting(windowEventIds) {
                notificationService.cancelNotifications(eventId: staleId)
            }
            NSLog("RedditReminder: notification permission not authorized (\(status.rawValue)) — skipping schedule")
            return
        }

        var activeEventIds: Set<String> = []
        let nudgeEnabled = UserDefaults.standard.object(forKey: "nudgeWhenEmpty") as? Bool ?? true

        let now = Date()
        for window in timingEngine.upcomingWindows {
            let eventId = window.event.id.uuidString
            activeEventIds.insert(eventId)

            // Skip scheduling if notification fire time is already past
            // (e.g., event in 30 min but lead time is 60 min).
            // A past-dated UNCalendarNotificationTrigger has undefined behavior.
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

        NSLog("RedditReminder: refresh complete — \(timingEngine.upcomingWindows.count) windows, \(staleIds.count) cancelled")
    }
}
