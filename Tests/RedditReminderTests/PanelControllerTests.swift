import Testing
import Foundation
@testable import RedditReminder

@MainActor
struct PanelControllerTests {
    @Test func statePersistsToUserDefaults() {
        let pc = PanelController()
        pc.state = .browse
        let saved = UserDefaults.standard.string(forKey: "sidebarState")
        #expect(saved == "browse")
    }

    @Test func captureRestoresToBrowse() {
        UserDefaults.standard.set("capture", forKey: "sidebarState")
        let result = PanelController.restoredState()
        #expect(result == .browse)
    }

    @Test func glanceRestoresAsGlance() {
        UserDefaults.standard.set("glance", forKey: "sidebarState")
        let result = PanelController.restoredState()
        #expect(result == .glance)
    }

    @Test func invalidDefaultsToGlance() {
        UserDefaults.standard.set("nonsense", forKey: "sidebarState")
        let result = PanelController.restoredState()
        #expect(result == .glance)
    }
}
