import AppKit
import SwiftUI

@MainActor
@Observable
final class MenuBarController: NSObject, NSPopoverDelegate, NSWindowDelegate {
    var badgeCount: Int = 0
    var isUrgent: Bool = false
    var isPopoverVisible: Bool = false

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var captureWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    /// Called from PopoverContentView to open new capture; wired to ⌘N.
    var onNewCapture: (() -> Void)?
    /// Called from PopoverContentView to open preferences; wired to ⌘,.
    var onOpenPreferences: (() -> Void)?

    func setup(popoverContent: some View) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "r.circle", accessibilityDescription: "RedditReminder")
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
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
            }
        }
    }

    // MARK: - Menu Shortcuts (⌘N, ⌘,)

    private func installMenuShortcuts() {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Preferences…",
            action: #selector(handleOpenPreferences),
            keyEquivalent: ","
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Quit RedditReminder",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        mainMenu.addItem(appMenuItem)

        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(
            withTitle: "New Capture",
            action: #selector(handleNewCapture),
            keyEquivalent: "n"
        )
        mainMenu.addItem(fileMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func handleNewCapture() {
        onNewCapture?()
    }

    @objc private func handleOpenPreferences() {
        onOpenPreferences?()
    }
}
