import Testing
import Foundation
@testable import RedditReminder

@Suite(.serialized)
@MainActor
struct MenuBarControllerTests {
    @Test func shortcutDefaultLoadsWhenUnset() {
        let suiteName = "ShortcutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(KeyboardShortcutConfig.load(from: defaults) == .defaultShortcut)
    }

    @Test func shortcutPersistsPresetIdentifier() {
        let suiteName = "ShortcutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let shortcut = KeyboardShortcutConfig.presets[1]

        KeyboardShortcutConfig.save(shortcut, to: defaults)

        #expect(KeyboardShortcutConfig.load(from: defaults) == shortcut)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func shortcutInvalidStoredIdentifierFallsBackToDefault() {
        let suiteName = "ShortcutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("missing", forKey: SettingsKey.globalShortcutIdentifier)

        #expect(KeyboardShortcutConfig.load(from: defaults) == .defaultShortcut)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func shortcutPresetsAreValid() {
        let allValid = KeyboardShortcutConfig.presets.allSatisfy { $0.isValid }
        #expect(allValid)
    }

    @Test func initialBadgeCountIsZero() {
        let controller = MenuBarController()
        #expect(controller.badgeCount == 0)
    }

    @Test func settingBadgeCountUpdatesProperty() {
        let controller = MenuBarController()
        controller.badgeCount = 5
        #expect(controller.badgeCount == 5)
    }

    @Test func isUrgentDefaultsToFalse() {
        let controller = MenuBarController()
        #expect(controller.isUrgent == false)
    }

    @Test func settingIsUrgentUpdatesProperty() {
        let controller = MenuBarController()
        controller.isUrgent = true
        #expect(controller.isUrgent == true)
    }

    @Test func popoverIsNotVisibleByDefault() {
        let controller = MenuBarController()
        #expect(controller.isPopoverVisible == false)
    }

    @Test func settingIsPopoverVisibleUpdatesProperty() {
        let controller = MenuBarController()
        controller.isPopoverVisible = true
        #expect(controller.isPopoverVisible == true)
    }

    @Test func handleNewCaptureInvokesCallback() {
        let controller = MenuBarController()
        var called = false
        controller.onNewCapture = { called = true }
        controller.perform(NSSelectorFromString("handleNewCapture"))
        #expect(called == true)
    }

    @Test func handleOpenPreferencesInvokesCallback() {
        let controller = MenuBarController()
        var called = false
        controller.onOpenPreferences = { called = true }
        controller.perform(NSSelectorFromString("handleOpenPreferences"))
        #expect(called == true)
    }

    @Test func handleNewCaptureNoOpWhenCallbackNil() {
        let controller = MenuBarController()
        // onNewCapture is nil by default — should not crash
        controller.perform(NSSelectorFromString("handleNewCapture"))
    }

    @Test func handleOpenPreferencesNoOpWhenCallbackNil() {
        let controller = MenuBarController()
        controller.perform(NSSelectorFromString("handleOpenPreferences"))
    }

}
