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
}
