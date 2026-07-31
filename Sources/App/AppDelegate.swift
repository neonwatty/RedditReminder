import AppKit
import SwiftData
import SwiftUI
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
  private var commandKeyMonitor: Any?
  var activeShortcutConfig: KeyboardShortcutConfig?
  private var settingsWindowController: NSWindowController?
  private var lifecycleAnchorWindow: NSWindow?

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
      menuBarController.onQAMarkFirstQueuedCapturePostedWithURL = { [weak self] in
        _ = self?.qaMarkFirstQueuedCapturePostedWithURL()
      }
      menuBarController.onQACreateTestCapture = { [weak self] in
        self?.qaCreateTestCapture()
      }
      menuBarController.onQACreateTitleOnlyTestCapture = { [weak self] in
        self?.qaCreateTitleOnlyTestCapture()
      }
      menuBarController.onQACreateMultiSubredditTestCapture = { [weak self] in
        self?.qaCreateMultiSubredditTestCapture()
      }
      menuBarController.onQADeleteTestCaptures = { [weak self] in
        self?.qaDeleteTestCaptures()
      }
      menuBarController.onQACopyFirstQueuedCaptureTitle = { [weak self] in
        self?.qaCopyFirstQueuedCaptureTitle()
      }
      menuBarController.onQACopyFirstQueuedCaptureSummary = { [weak self] in
        self?.qaCopyFirstQueuedCaptureSummary()
      }
      menuBarController.onQACopyFirstPostedCaptureSummary = { [weak self] in
        self?.qaCopyFirstPostedCaptureSummary()
      }
      menuBarController.onQACopyFirstPostedURL = { [weak self] in
        self?.qaCopyFirstPostedURL()
      }
    #endif
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !AppRuntime.isRunningUnitTests() else {
      NSLog("RedditReminder: launched in unit test mode")
      return
    }

    ProcessInfo.processInfo.disableAutomaticTermination(
      "Keep RedditReminder menu bar app running"
    )
    bootstrapApplication()
    setupLifecycleAnchorWindow()
    installCommandKeyMonitor()

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

    configureNotificationsOnLaunch()

    startRefreshLoop()

    NSLog("RedditReminder: launched, refresh loop started")
  }

  func configureNotificationsOnLaunch() {
    UNUserNotificationCenter.current().delegate = self
    notificationService.registerCategories()
  }

  private func bootstrapApplication() {
    let container: ModelContainer
    do {
      container = try AppModelContainerFactory.makeContainer(storeURL: AppRuntime.uiTestStoreURL())
    } catch {
      presentStoreUnavailableAlert(error: error)
      return
    }

    wireMenuActions(container: container)
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains(QAFixtures.seedLaunchArgument) {
        QAFixtures.seed(context: container.mainContext, mediaStore: mediaStore)
      } else if ProcessInfo.processInfo.arguments.contains(QAFixtures.clearLaunchArgument) {
        QAFixtures.clearAll(context: container.mainContext, mediaStore: mediaStore)
      }
    #endif
    runRefreshCycle()

    let popoverView = PopoverContentView(
      menuBarController: menuBarController,
      notificationService: notificationService,
      heuristicsStore: heuristicsStore,
      onAppStateChanged: { [weak self] in self?.runRefreshCycle() }
    )
    .modelContainer(container)
    menuBarController.setup(popoverContent: popoverView)
  }

  private func presentStoreUnavailableAlert(error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "RedditReminder cannot open its data store"
    alert.informativeText = """
      The app did not start with temporary storage because that could make new captures disappear when you quit.

      \(error.localizedDescription)
      """
    alert.addButton(withTitle: "Reveal Data Folder")
    alert.addButton(withTitle: "Quit")
    if alert.runModal() == .alertFirstButtonReturn {
      let directory = AppModelContainerFactory.appSupportDirectory
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
    NSApp.terminate(nil)
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    menuBarController.installMenuShortcuts()
  }

  func applicationWillTerminate(_ notification: Notification) {
    globalShortcut.unregister()
    refreshTask?.cancel()
    settingsWindowController?.close()
    settingsWindowController = nil
    lifecycleAnchorWindow?.close()
    lifecycleAnchorWindow = nil
    ProcessInfo.processInfo.enableAutomaticTermination(
      "Keep RedditReminder menu bar app running"
    )
    if let shortcutObserver {
      NotificationCenter.default.removeObserver(shortcutObserver)
    }
    if let commandKeyMonitor {
      NSEvent.removeMonitor(commandKeyMonitor)
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  private func setupLifecycleAnchorWindow() {
    guard lifecycleAnchorWindow == nil else { return }

    let window = NSWindow(
      contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.level = .popUpMenu
    window.alphaValue = 0
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    window.orderFrontRegardless()
    lifecycleAnchorWindow = window
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

  private func installCommandKeyMonitor() {
    guard commandKeyMonitor == nil else { return }
    commandKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      guard
        flags.contains(.command),
        !flags.contains(.option),
        !flags.contains(.control),
        !flags.contains(.shift),
        let key = event.charactersIgnoringModifiers?.lowercased()
      else {
        return event
      }

      switch key {
      case "n", ",", "w":
        Task { @MainActor [weak self] in
          self?.handleCommandKey(key)
        }
        return nil
      default:
        return event
      }
    }
  }

  private func handleCommandKey(_ key: String) {
    switch key {
    case "n":
      settingsWindowController?.window?.performClose(nil)
      menuBarController.requestNewCapture()
    case ",":
      openSettingsWindow()
    case "w":
      let window = NSApp.keyWindow ?? NSApp.orderedWindows.first { window in
        window.isVisible && window.canBecomeKey
      }
      window?.performClose(nil)
    default:
      break
    }
  }

  func runRefreshCycle() {
    guard let container = modelContainer else {
      NSLog("RedditReminder: refresh skipped — no ModelContainer")
      return
    }

    let context = container.mainContext

    do {
      try syncGeneratedEventsForRefresh(context: context)
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
      self?.settingsWindowController?.window?.performClose(nil)
      self?.menuBarController.requestNewCapture()
    }
    menuBarController.onOpenPreferences = { [weak self] tab in
      self?.openSettingsWindow(initialTab: tab)
    }
  }

  func openSettingsWindow(initialTab: PreferencesView.Tab = PreferencesView.defaultTab) {
    guard let container = modelContainer else {
      NSLog("RedditReminder: settings skipped — no ModelContainer")
      return
    }

    menuBarController.dismissPopover()
    menuBarController.installMenuShortcuts()

    let settingsView = PreferencesView(
      notificationService: notificationService,
      heuristicsStore: heuristicsStore,
      initialTab: initialTab,
      onAppStateChanged: { [weak self] in self?.runRefreshCycle() }
    )
    .modelContainer(container)
    .frame(minWidth: 520, idealWidth: 560, minHeight: 360, idealHeight: 420)

    let hostingController = NSHostingController(rootView: settingsView)

    if let window = settingsWindowController?.window {
      window.contentViewController = hostingController
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      menuBarController.installMenuShortcuts()
      return
    }

    let window = NSWindow(contentViewController: hostingController)
    window.title = "Settings"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.minSize = NSSize(width: 520, height: 360)
    window.isReleasedWhenClosed = false
    window.center()

    let controller = NSWindowController(window: window)
    settingsWindowController = controller
    controller.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
    menuBarController.installMenuShortcuts()
  }

  private var defaultLeadTimeMinutes: Int {
    defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
  }

  func syncGeneratedEventsForRefresh(context: ModelContext) throws {
    let subreddits = try context.fetch(FetchDescriptor<Subreddit>())
    try heuristicsStore.syncGeneratedEvents(
      for: subreddits,
      context: context,
      defaultLeadTimeMinutes: defaultLeadTimeMinutes,
      notificationService: notificationService
    )
  }

  func scheduleNotifications(activeEvents: [SubredditEvent], windows: [TimingEngine.UpcomingWindow])
    async
  {
    _ = await notificationScheduler.schedule(activeEvents: activeEvents, windows: windows)
  }
}
