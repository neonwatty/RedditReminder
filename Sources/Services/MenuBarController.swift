import AppKit
import SwiftUI

@MainActor
@Observable
final class MenuBarController: NSObject, NSPopoverDelegate {
  static let settingsMenuItemTitle = "Settings…"

  var badgeCount: Int = 0
  var isUrgent: Bool = false
  var isPopoverVisible: Bool = false
  var newCaptureRequestCount: Int = 0
  var preferencesRequestCount: Int = 0

  private var statusItem: NSStatusItem?
  private var popover: NSPopover?

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
    var onQACreateTitleOnlyTestCapture: (() -> Void)?
    var onQACreateMultiSubredditTestCapture: (() -> Void)?
    var onQADeleteTestCaptures: (() -> Void)?
    var onQACopyFirstQueuedCaptureTitle: (() -> Void)?
    var onQACopyFirstQueuedCaptureSummary: (() -> Void)?
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
    pop.contentSize = NSSize(width: 460, height: 620)
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

  func requestNewCapture() {
    newCaptureRequestCount += 1
    openPopover()
  }

  func requestPreferences() {
    preferencesRequestCount += 1
    openPopover()
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

}
