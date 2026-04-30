import AppKit
import SwiftUI

@MainActor
@Observable
final class MenuBarController: NSObject, NSPopoverDelegate, NSWindowDelegate {
  static let settingsMenuItemTitle = "Settings…"

  var badgeCount: Int = 0
  var isUrgent: Bool = false
  var isPopoverVisible: Bool = false

  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var captureWindow: NSWindow?
  private var preferencesWindow: NSWindow?
  private var postHandoffWindow: NSWindow?

  /// Called from PopoverContentView to open new capture; wired to ⌘N.
  var onNewCapture: (() -> Void)?
  /// Called from PopoverContentView to open settings; wired to ⌘,.
  var onOpenPreferences: (() -> Void)?
  #if DEBUG
    var onQACopyFirstQueuedCapture: (() -> Void)?
    var onQACopyFirstQueuedSubmitURL: (() -> Void)?
    var onQAMarkFirstQueuedCapturePosted: (() -> Void)?
    var onQAMarkFirstQueuedCapturePostedWithURL: (() -> Void)?
    var onQACreateTestCapture: (() -> Void)?
    var onQADeleteTestCaptures: (() -> Void)?
    var onQACopyFirstQueuedCaptureTitle: (() -> Void)?
    var onQACopyFirstPostedCaptureSummary: (() -> Void)?
    var onQACopyFirstPostedURL: (() -> Void)?
  #endif

  func setup(popoverContent: some View) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = item.button {
      button.image = NSImage(
        systemSymbolName: "r.circle", accessibilityDescription: "RedditReminder")
      button.image?.isTemplate = true
      button.action = #selector(statusItemClicked)
      button.target = self
    }

    let pop = NSPopover()
    pop.contentSize = NSSize(width: 350, height: 480)
    pop.behavior = .transient
    pop.animates = true
    pop.contentViewController = NSHostingController(rootView: popoverContent)
    pop.delegate = self

    self.statusItem = item
    self.popover = pop

    installMenuShortcuts()
  }

  @objc private func statusItemClicked() {
    togglePopover()
  }

  func togglePopover() {
    guard let popover, let button = statusItem?.button else { return }

    if popover.isShown {
      popover.performClose(nil)
      isPopoverVisible = false
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      isPopoverVisible = true
    }
  }

  func openPopover() {
    guard let popover, let button = statusItem?.button, !popover.isShown else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    isPopoverVisible = true
  }

  func showCaptureWindow(title: String = "New Capture", content: some View) {
    // Always recreate window content so edit-after-edit shows fresh data
    if let existing = captureWindow {
      existing.title = title
      existing.contentView = NSHostingView(rootView: content)
      existing.makeKeyAndOrderFront(nil)
      dismissPopover()
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 540),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = title
    window.center()
    window.contentView = NSHostingView(rootView: content)
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.makeKeyAndOrderFront(nil)

    dismissPopover()
    self.captureWindow = window
  }

  func closeCaptureWindow() {
    captureWindow?.close()
    captureWindow = nil
  }

  func showPostHandoffWindow(title: String = "Post Handoff", content: some View) {
    if let existing = postHandoffWindow {
      existing.title = title
      existing.contentView = NSHostingView(rootView: content)
      existing.makeKeyAndOrderFront(nil)
      dismissPopover()
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = title
    window.center()
    window.contentView = NSHostingView(rootView: content)
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.makeKeyAndOrderFront(nil)

    dismissPopover()
    self.postHandoffWindow = window
  }

  func closePostHandoffWindow() {
    postHandoffWindow?.close()
    postHandoffWindow = nil
  }

  func showPreferencesWindow(content: some View) {
    if let existing = preferencesWindow {
      existing.makeKeyAndOrderFront(nil)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "RedditReminder Preferences"
    window.center()
    window.contentView = NSHostingView(rootView: content)
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.makeKeyAndOrderFront(nil)

    dismissPopover()
    self.preferencesWindow = window
  }

  func closePreferencesWindow() {
    preferencesWindow?.close()
    preferencesWindow = nil
  }

  func dismissPopover() {
    popover?.performClose(nil)
    isPopoverVisible = false
  }

  func updateIcon() {
    guard let button = statusItem?.button else { return }

    if isUrgent {
      let config = NSImage.SymbolConfiguration(
        paletteColors: [AppColors.reddit]
      )
      button.image = NSImage(
        systemSymbolName: "r.circle.fill",
        accessibilityDescription: "RedditReminder — urgent"
      )?.withSymbolConfiguration(config)
      button.image?.isTemplate = false
    } else {
      button.image = NSImage(
        systemSymbolName: "r.circle",
        accessibilityDescription: "RedditReminder"
      )
      button.image?.isTemplate = true
    }

    if badgeCount > 0 {
      button.title = "\(badgeCount)"
      button.imagePosition = .imageLeading
    } else {
      button.title = ""
      button.imagePosition = .imageOnly
    }
  }

  // MARK: - NSPopoverDelegate

  nonisolated func popoverDidClose(_ notification: Notification) {
    Task { @MainActor in
      self.isPopoverVisible = false
    }
  }

  // MARK: - NSWindowDelegate

  nonisolated func windowWillClose(_ notification: Notification) {
    let window = notification.object as? NSWindow
    Task { @MainActor in
      if window === self.captureWindow {
        self.captureWindow = nil
      } else if window === self.preferencesWindow {
        self.preferencesWindow = nil
      } else if window === self.postHandoffWindow {
        self.postHandoffWindow = nil
      }
    }
  }

  // MARK: - Menu Shortcuts (⌘N, ⌘,)

  func installMenuShortcuts() {
    let mainMenu = NSMenu()

    let appMenu = NSMenu()
    let appMenuItem = NSMenuItem(title: "RedditReminder", action: nil, keyEquivalent: "")
    appMenuItem.submenu = appMenu
    let prefsItem = NSMenuItem(
      title: Self.settingsMenuItemTitle, action: #selector(handleOpenPreferences),
      keyEquivalent: ",")
    prefsItem.target = self
    appMenu.addItem(prefsItem)
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(
      withTitle: "Quit RedditReminder",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    mainMenu.addItem(appMenuItem)

    let fileMenu = NSMenu(title: "File")
    let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    fileMenuItem.submenu = fileMenu
    let newCaptureItem = NSMenuItem(
      title: "New Capture", action: #selector(handleNewCapture), keyEquivalent: "n")
    newCaptureItem.target = self
    fileMenu.addItem(newCaptureItem)
    mainMenu.addItem(fileMenuItem)

    #if DEBUG
      let qaMenu = NSMenu(title: "QA")
      let qaMenuItem = NSMenuItem(title: "QA", action: nil, keyEquivalent: "")
      qaMenuItem.submenu = qaMenu

      let copyCaptureItem = NSMenuItem(
        title: "Copy First Queued Capture",
        action: #selector(handleQACopyFirstQueuedCapture),
        keyEquivalent: ""
      )
      copyCaptureItem.target = self
      qaMenu.addItem(copyCaptureItem)

      let copyTitleItem = NSMenuItem(
        title: "Copy First Queued Capture Title",
        action: #selector(handleQACopyFirstQueuedCaptureTitle),
        keyEquivalent: ""
      )
      copyTitleItem.target = self
      qaMenu.addItem(copyTitleItem)

      let copySubmitURLItem = NSMenuItem(
        title: "Copy First Queued Submit URL",
        action: #selector(handleQACopyFirstQueuedSubmitURL),
        keyEquivalent: ""
      )
      copySubmitURLItem.target = self
      qaMenu.addItem(copySubmitURLItem)

      let markPostedItem = NSMenuItem(
        title: "Mark First Queued Capture Posted",
        action: #selector(handleQAMarkFirstQueuedCapturePosted),
        keyEquivalent: ""
      )
      markPostedItem.target = self
      qaMenu.addItem(markPostedItem)

      let markPostedWithURLItem = NSMenuItem(
        title: "Mark First Queued Capture Posted With URL",
        action: #selector(handleQAMarkFirstQueuedCapturePostedWithURL),
        keyEquivalent: ""
      )
      markPostedWithURLItem.target = self
      qaMenu.addItem(markPostedWithURLItem)

      let copyPostedSummaryItem = NSMenuItem(
        title: "Copy First Posted Capture Summary",
        action: #selector(handleQACopyFirstPostedCaptureSummary),
        keyEquivalent: ""
      )
      copyPostedSummaryItem.target = self
      qaMenu.addItem(copyPostedSummaryItem)

      let copyPostedURLItem = NSMenuItem(
        title: "Copy First Posted URL",
        action: #selector(handleQACopyFirstPostedURL),
        keyEquivalent: ""
      )
      copyPostedURLItem.target = self
      qaMenu.addItem(copyPostedURLItem)

      qaMenu.addItem(NSMenuItem.separator())

      let createTestCaptureItem = NSMenuItem(
        title: "Create Test Capture",
        action: #selector(handleQACreateTestCapture),
        keyEquivalent: ""
      )
      createTestCaptureItem.target = self
      qaMenu.addItem(createTestCaptureItem)

      let deleteTestCapturesItem = NSMenuItem(
        title: "Delete Test Captures",
        action: #selector(handleQADeleteTestCaptures),
        keyEquivalent: ""
      )
      deleteTestCapturesItem.target = self
      qaMenu.addItem(deleteTestCapturesItem)

      mainMenu.addItem(qaMenuItem)
    #endif

    NSApp.mainMenu = mainMenu
  }

  @objc private func handleNewCapture() {
    onNewCapture?()
  }

  @objc private func handleOpenPreferences() {
    onOpenPreferences?()
  }

  #if DEBUG
    @objc private func handleQACopyFirstQueuedCapture() {
      onQACopyFirstQueuedCapture?()
    }

    @objc private func handleQACopyFirstQueuedSubmitURL() {
      onQACopyFirstQueuedSubmitURL?()
    }

    @objc private func handleQAMarkFirstQueuedCapturePosted() {
      onQAMarkFirstQueuedCapturePosted?()
    }

    @objc private func handleQAMarkFirstQueuedCapturePostedWithURL() {
      onQAMarkFirstQueuedCapturePostedWithURL?()
    }

    @objc private func handleQACreateTestCapture() {
      onQACreateTestCapture?()
    }

    @objc private func handleQADeleteTestCaptures() {
      onQADeleteTestCaptures?()
    }

    @objc private func handleQACopyFirstQueuedCaptureTitle() {
      onQACopyFirstQueuedCaptureTitle?()
    }

    @objc private func handleQACopyFirstPostedCaptureSummary() {
      onQACopyFirstPostedCaptureSummary?()
    }

    @objc private func handleQACopyFirstPostedURL() {
      onQACopyFirstPostedURL?()
    }
  #endif
}
