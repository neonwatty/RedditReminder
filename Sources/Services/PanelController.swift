import AppKit
import SwiftUI
import Observation

@MainActor
@Observable
final class PanelController {
    var state: SidebarState = .glance
    var screenEdge: ScreenEdge = .right

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var autoCollapseTimer: Timer?
    private var restingState: SidebarState = .glance
    private var autoCollapseMinutes: Int = SidebarConstants.defaultAutoCollapseMinutes

    enum ScreenEdge { case left, right }

    func setup(contentView: some View) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: SidebarConstants.glanceWidth, height: 0),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true
        panel.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.16, alpha: 1.0)
        panel.isOpaque = false

        let hosting = NSHostingView(rootView: AnyView(contentView))
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting

        positionPanel()
        panel.orderFront(nil)
        resetAutoCollapseTimer()
    }

    func setState(_ newState: SidebarState) {
        state = newState
        animateWidth()
        resetAutoCollapseTimer()
    }

    func stepDown() {
        let states = SidebarState.allCases
        guard let idx = states.firstIndex(of: state), idx > 0 else { return }
        setState(states[idx - 1])
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
