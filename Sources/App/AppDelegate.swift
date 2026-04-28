import AppKit
import SwiftData
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let menuBarController: MenuBarController
    let timingEngine: TimingEngine
    let notificationService: NotificationService
    let heuristicsStore: HeuristicsStore
    let notificationScheduler: NotificationScheduler
    let defaults: UserDefaults

    var modelContainer: ModelContainer?

    private let globalShortcut = GlobalShortcut()
    private var refreshTask: Task<Void, Never>?
    private var shortcutObserver: NSObjectProtocol?
    private var activeShortcutConfig: KeyboardShortcutConfig?

    override convenience init() {
        self.init(
            menuBarController: MenuBarController(),
            timingEngine: TimingEngine(),
            notificationService: NotificationService(),
            heuristicsStore: HeuristicsStore()
        )
    }

    init(
        menuBarController: MenuBarController,
        timingEngine: TimingEngine,
        notificationService: NotificationService,
        heuristicsStore: HeuristicsStore,
        defaults: UserDefaults = .standard
    ) {
        self.menuBarController = menuBarController
        self.timingEngine = timingEngine
        self.notificationService = notificationService
        self.heuristicsStore = heuristicsStore
        self.defaults = defaults
        self.notificationScheduler = NotificationScheduler(notificationService: notificationService, defaults: defaults)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppRuntime.shouldRegisterGlobalShortcut() {
            registerGlobalShortcut()
            shortcutObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.registerGlobalShortcut()
                }
            }
        }

        UNUserNotificationCenter.current().delegate = self
        notificationService.registerCategories()

        Task { _ = await notificationService.requestPermission() }

        startRefreshLoop()

        NSLog("RedditReminder: launched, refresh loop started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcut.unregister()
        refreshTask?.cancel()
        if let shortcutObserver {
            NotificationCenter.default.removeObserver(shortcutObserver)
        }
    }

    private func registerGlobalShortcut() {
        let config = KeyboardShortcutConfig.load()
        guard config != activeShortcutConfig else { return }
        let registered = globalShortcut.register(config: config) { [weak self] in
            MainActor.assumeIsolated {
                self?.menuBarController.togglePopover()
            }
        }
        if registered {
            activeShortcutConfig = config
            NSLog("RedditReminder: \(config.display) registered")
        } else {
            activeShortcutConfig = nil
        }
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

        let subreddits: [Subreddit]

        do {
            subreddits = try context.fetch(FetchDescriptor<Subreddit>())
            try heuristicsStore.syncGeneratedEvents(
                for: subreddits,
                context: context,
                defaultLeadTimeMinutes: defaultLeadTimeMinutes
            )
        } catch {
            NSLog("RedditReminder: heuristic event sync failed: \(error)")
        }

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

    private var defaultLeadTimeMinutes: Int { defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60 }

    func scheduleNotifications(
        activeEvents: [SubredditEvent],
        windows: [TimingEngine.UpcomingWindow]
    ) async {
        _ = await notificationScheduler.schedule(activeEvents: activeEvents, windows: windows)
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
