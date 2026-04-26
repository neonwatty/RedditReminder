import AppKit
import SwiftUI
import Observation

/// NSPanel subclass that can become key even when borderless.
/// Required so SwiftUI gesture recognizers receive mouse events.
final class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// NSHostingView subclass that accepts first-mouse clicks and
/// makes the panel key on mouseDown so SwiftUI gestures fire.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }
}

@MainActor
@Observable
final class PanelController {
    var state: SidebarState = .glance {
        didSet {
            UserDefaults.standard.set(state.rawValue, forKey: "sidebarState")
        }
    }
    var screenEdge: ScreenEdge = .right

    private var panel: NSPanel?
    private var hostingView: FirstMouseHostingView<AnyView>?
    private var autoCollapseTimer: Timer?
    private var restingState: SidebarState = .glance
    private var autoCollapseMinutes: Int = SidebarConstants.defaultAutoCollapseMinutes
    private var previousState: SidebarState = .glance

    enum ScreenEdge { case left, right }

    func setup(contentView: some View) {
        let restored = Self.restoredState()

        let panel = ClickablePanel(
            contentRect: NSRect(x: 0, y: 0, width: SidebarConstants.glanceWidth, height: 0),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true
        panel.backgroundColor = NSColor(red: 0.07, green: 0.08, blue: 0.14, alpha: 1.0)
        panel.isOpaque = false
        panel.contentMinSize = NSSize(width: 1, height: 1)
        panel.minSize = NSSize(width: 1, height: 1)

        let hosting = FirstMouseHostingView(rootView: AnyView(contentView))
        hosting.sizingOptions = []
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting

        // Position at glance width (200pt) first so NSHostingView completes its
        // initial layout without fighting the frame. Then restore the saved state
        // (e.g. .strip at 24pt) and animate to it. Without this, NSHostingView's
        // intrinsic sizing overrides narrow widths on cold start.
        state = .glance
        positionPanel()
        panel.orderFront(nil)

        if restored != .glance {
            state = restored
            animateWidth()
        }
        resetAutoCollapseTimer()
    }

    func setState(_ newState: SidebarState) {
        state = newState
        animateWidth()
        resetAutoCollapseTimer()
    }

    func goToSettings() {
        guard state != .settings else { return }
        // Don't save .strip as previousState — it has no header to navigate back from
        previousState = (state == .strip) ? .glance : state
        setState(.settings)
    }

    func stepDown() {
        if state == .settings || state == .channels {
            setState(previousState)
            return
        }
        let ladder: [SidebarState] = [.strip, .glance, .browse, .capture]
        guard let idx = ladder.firstIndex(of: state), idx > 0 else { return }
        setState(ladder[idx - 1])
    }

    func toggleCapture() {
        if state == .capture {
            setState(.browse)
        } else {
            setState(.capture)
        }
    }

    func setScreenEdge(_ edge: ScreenEdge) {
        screenEdge = edge
        positionPanel()
    }

    func setAutoCollapse(minutes: Int, restingState: SidebarState) {
        self.autoCollapseMinutes = minutes
        self.restingState = restingState
        resetAutoCollapseTimer()
    }

    static func restoredState(from defaults: UserDefaults = .standard) -> SidebarState {
        guard let saved = defaults.string(forKey: "sidebarState"),
              let restored = SidebarState(rawValue: saved) else {
            return .glance
        }
        switch restored {
        case .capture: return .browse
        case .settings: return .glance
        case .channels: return .glance
        default: return restored
        }
    }

    private func animateWidth() {
        guard let panel else { return }
        let targetWidth = SidebarConstants.width(for: state)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = SidebarConstants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            var frame = panel.frame
            let widthDelta = targetWidth - frame.width

            if screenEdge == .right {
                frame.origin.x -= widthDelta
            }
            frame.size.width = targetWidth

            panel.animator().setFrame(frame, display: true)
        }
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let width = SidebarConstants.width(for: state)

        let x: CGFloat
        if screenEdge == .right {
            x = screenFrame.maxX - width
        } else {
            x = screenFrame.minX
        }

        let frame = NSRect(
            x: x,
            y: screenFrame.minY,
            width: width,
            height: screenFrame.height
        )
        panel.setFrame(frame, display: true)
    }

    private func resetAutoCollapseTimer() {
        autoCollapseTimer?.invalidate()
        guard autoCollapseMinutes > 0 else { return }

        autoCollapseTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(autoCollapseMinutes * 60),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.state.isWiderThan(self.restingState) {
                    self.setState(self.restingState)
                }
            }
        }
    }
}

extension SidebarState {
    func isWiderThan(_ other: SidebarState) -> Bool {
        SidebarConstants.width(for: self) > SidebarConstants.width(for: other)
    }
}
