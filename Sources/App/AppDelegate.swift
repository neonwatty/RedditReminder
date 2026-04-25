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
        // Also run immediately on launch
        runRefreshCycle()
    }

    private func runRefreshCycle() {
        guard let container = modelContainer else {
            NSLog("RedditReminder: refresh skipped — no ModelContainer")
            return
        }

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

        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard notificationsEnabled else {
            notificationService.cancelAll()
            NSLog("RedditReminder: notifications disabled — cancelled all, skipping schedule")
            return
        }

        // Track which event IDs have active windows
        var activeEventIds: Set<String> = []

        let nudgeEnabled = UserDefaults.standard.bool(forKey: "nudgeWhenEmpty")

        for window in timingEngine.upcomingWindows {
            let eventId = window.event.id.uuidString
            activeEventIds.insert(eventId)

            notificationService.scheduleWindowNotification(
                eventId: eventId,
                title: window.event.name,
                body: "\(window.matchingCaptureCount) captures ready for \(window.event.subreddit?.name ?? "subreddit")",
                fireDate: window.fireDate
            )

            if window.matchingCaptureCount == 0 && nudgeEnabled {
                notificationService.scheduleEmptyQueueNudge(
                    eventId: eventId,
                    subredditName: window.event.subreddit?.name ?? "subreddit",
                    eventName: window.event.name,
                    fireDate: window.fireDate
                )
            }
        }

        // Cancel notifications for events no longer in the active window set
        let allEventIds = Set(activeEvents.map { $0.id.uuidString })
        let staleIds = allEventIds.subtracting(activeEventIds)
        for staleId in staleIds {
            notificationService.cancelNotifications(eventId: staleId)
        }

        NSLog("RedditReminder: refresh complete — \(timingEngine.upcomingWindows.count) windows, \(staleIds.count) cancelled")
    }
}
