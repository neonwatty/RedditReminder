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
  let openPopoverForNotificationAction: @MainActor () -> Void
  let mediaStore = MediaStore()

  var modelContainer: ModelContainer?

  let globalShortcut: any GlobalShortcutRegistering
  private var refreshTask: Task<Void, Never>?
  private var shortcutObserver: NSObjectProtocol?
  var activeShortcutConfig: KeyboardShortcutConfig?

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
    defaults: UserDefaults = .standard,
    globalShortcut: any GlobalShortcutRegistering = GlobalShortcut(),
    notificationActionPopoverOpener: (@MainActor () -> Void)? = nil
  ) {
    self.menuBarController = menuBarController
    self.timingEngine = timingEngine
    self.notificationService = notificationService
    self.heuristicsStore = heuristicsStore
    self.defaults = defaults
    self.globalShortcut = globalShortcut
    self.openPopoverForNotificationAction =
      notificationActionPopoverOpener ?? {
        menuBarController.openPopover()
      }
    self.notificationScheduler = NotificationScheduler(
      notificationService: notificationService, defaults: defaults)
    super.init()
    #if DEBUG
      menuBarController.onQACopyFirstQueuedCapture = { [weak self] in
        self?.qaCopyFirstQueuedCapture()
      }
      menuBarController.onQACopyFirstQueuedSubmitURL = { [weak self] in
        self?.qaCopyFirstQueuedSubmitURL()
      }
      menuBarController.onQAMarkFirstQueuedCapturePosted = { [weak self] in
        self?.qaMarkFirstQueuedCapturePosted()
      }
      menuBarController.onQACreateTestCapture = { [weak self] in
        self?.qaCreateTestCapture()
      }
      menuBarController.onQADeleteTestCaptures = { [weak self] in
        self?.qaDeleteTestCaptures()
      }
      menuBarController.onQACopyFirstQueuedCaptureTitle = { [weak self] in
        self?.qaCopyFirstQueuedCaptureTitle()
      }
    #endif
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

  func applicationDidBecomeActive(_ notification: Notification) {
    menuBarController.installMenuShortcuts()
  }

  func applicationWillTerminate(_ notification: Notification) {
    globalShortcut.unregister()
    refreshTask?.cancel()
    if let shortcutObserver {
      NotificationCenter.default.removeObserver(shortcutObserver)
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
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

  func wireMenuActions(container: ModelContainer) {
    modelContainer = container
    menuBarController.onNewCapture = { [weak self] in
      self?.showNewCaptureWindow(container: container)
    }
    menuBarController.onOpenPreferences = { [weak self] in
      self?.showPreferencesWindow(container: container)
    }
  }

  private func showNewCaptureWindow(container: ModelContainer) {
    let formView = CaptureWindowView(
      mode: .create,
      onSave: { [weak self] result in
        guard let self else { return false }
        let ok = CapturePersistenceActions.saveCapture(
          result,
          modelContext: container.mainContext,
          mediaStore: mediaStore,
          onAppStateChanged: { [weak self] in self?.runRefreshCycle() }
        )
        if ok {
          menuBarController.closeCaptureWindow()
          menuBarController.openPopover()
        }
        return ok
      },
      onCancel: { [weak self] in self?.menuBarController.closeCaptureWindow() }
    )
    .modelContainer(container)
    menuBarController.showCaptureWindow(title: "New Capture", content: formView)
  }

  private func showPreferencesWindow(container: ModelContainer) {
    let prefsView = PreferencesView(
      notificationService: notificationService,
      heuristicsStore: heuristicsStore,
      onAppStateChanged: { [weak self] in self?.runRefreshCycle() }
    )
    .modelContainer(container)
    menuBarController.showPreferencesWindow(content: prefsView)
  }

  private var defaultLeadTimeMinutes: Int {
    defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
  }

  func scheduleNotifications(
    activeEvents: [SubredditEvent],
    windows: [TimingEngine.UpcomingWindow]
  ) async {
    _ = await notificationScheduler.schedule(activeEvents: activeEvents, windows: windows)
  }

}
