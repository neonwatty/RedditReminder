import AppKit
import SwiftUI

@MainActor
@Observable
final class MenuBarController {
    var badgeCount: Int = 0
    var isUrgent: Bool = false
    var isPopoverVisible: Bool = false

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var captureWindow: NSWindow?
    private var preferencesWindow: NSWindow?

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

        self.statusItem = item
        self.popover = pop
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

    func showCaptureWindow(content: some View) {
        if let existing = captureWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "New Capture"
        window.center()
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
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
                paletteColors: [NSColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0)]
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
}
