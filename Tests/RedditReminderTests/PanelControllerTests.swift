import Testing
import Foundation
@testable import RedditReminder

@MainActor
struct PanelControllerTests {
    private let testDefaults = UserDefaults(suiteName: "PanelControllerTests")!

    init() {
        testDefaults.removePersistentDomain(forName: "PanelControllerTests")
    }

    @Test func statePersistsToUserDefaults() {
        let pc = PanelController()
        pc.state = .browse
        let saved = UserDefaults.standard.string(forKey: "sidebarState")
        #expect(saved == "browse")
        UserDefaults.standard.removeObject(forKey: "sidebarState")
    }

    @Test func captureRestoresToBrowse() {
        testDefaults.set("capture", forKey: "sidebarState")
        let result = PanelController.restoredState(from: testDefaults)
        #expect(result == .browse)
    }

    @Test func glanceRestoresAsGlance() {
        testDefaults.set("glance", forKey: "sidebarState")
        let result = PanelController.restoredState(from: testDefaults)
        #expect(result == .glance)
    }

    @Test func settingsRestoresToGlance() {
        testDefaults.set("settings", forKey: "sidebarState")
        let result = PanelController.restoredState(from: testDefaults)
        #expect(result == .glance)
    }

    @Test func invalidDefaultsToGlance() {
        testDefaults.set("nonsense", forKey: "sidebarState")
        let result = PanelController.restoredState(from: testDefaults)
        #expect(result == .glance)
    }

    @Test func nilDefaultsToGlance() {
        let result = PanelController.restoredState(from: testDefaults)
        #expect(result == .glance)
    }

    // MARK: - setAutoCollapse

    @Test func setAutoCollapseAcceptsValidInputs() {
        let pc = PanelController()
        pc.setAutoCollapse(minutes: 10, restingState: .strip)
        pc.setAutoCollapse(minutes: 5, restingState: .glance)
        pc.setAutoCollapse(minutes: 30, restingState: .browse)
        // No crash = pass; values are private but timer is reset each call
    }

    @Test func setAutoCollapseZeroDisablesTimer() {
        let pc = PanelController()
        pc.state = .browse
        pc.setAutoCollapse(minutes: 0, restingState: .strip)
        // With minutes=0, timer should not fire — state remains unchanged
        #expect(pc.state == .browse)
    }

    // MARK: - isWiderThan

    @Test func isWiderThanComparesCorrectly() {
        #expect(SidebarState.capture.isWiderThan(.browse))
        #expect(SidebarState.browse.isWiderThan(.glance))
        #expect(SidebarState.glance.isWiderThan(.strip))
        #expect(!SidebarState.strip.isWiderThan(.glance))
        #expect(!SidebarState.glance.isWiderThan(.browse))
        #expect(!SidebarState.glance.isWiderThan(.glance))
    }

    // MARK: - stepDown / toggleCapture

    @Test func stepDownFollowsLadder() {
        let pc = PanelController()
        pc.state = .capture
        pc.stepDown()
        #expect(pc.state == .browse)
        pc.stepDown()
        #expect(pc.state == .glance)
        pc.stepDown()
        #expect(pc.state == .strip)
        pc.stepDown()
        #expect(pc.state == .strip)  // can't go below strip
    }

    @Test func stepDownFromSettingsReturnsToPreviousState() {
        let pc = PanelController()
        pc.state = .browse
        pc.goToSettings()
        #expect(pc.state == .settings)
        pc.stepDown()
        #expect(pc.state == .browse)
    }

    @Test func toggleCaptureFlipsBetweenCaptureAndBrowse() {
        let pc = PanelController()
        pc.state = .glance
        pc.toggleCapture()
        #expect(pc.state == .capture)
        pc.toggleCapture()
        #expect(pc.state == .browse)
    }
}
