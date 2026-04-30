import AppKit
import Foundation
import Testing

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

  @Test func shortcutPresetClearsStaleCustomValues() {
    let suiteName = "ShortcutTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let custom = KeyboardShortcutConfig.custom(
      keyCode: 35,
      modifiers: [.maskCommand, .maskAlternate],
      keyDisplay: "P"
    )

    KeyboardShortcutConfig.save(custom, to: defaults)
    KeyboardShortcutConfig.save(KeyboardShortcutConfig.presets[1], to: defaults)

    #expect(defaults.object(forKey: SettingsKey.globalShortcutKeyCode) == nil)
    #expect(defaults.object(forKey: SettingsKey.globalShortcutModifiers) == nil)
    #expect(defaults.object(forKey: SettingsKey.globalShortcutDisplay) == nil)
    defaults.removePersistentDomain(forName: suiteName)
  }

  @Test func shortcutInvalidStoredIdentifierFallsBackToDefault() {
    let suiteName = "ShortcutTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set("missing", forKey: SettingsKey.globalShortcutIdentifier)

    #expect(KeyboardShortcutConfig.load(from: defaults) == .defaultShortcut)
    defaults.removePersistentDomain(forName: suiteName)
  }

  @Test func shortcutPersistsCustomConfig() {
    let suiteName = "ShortcutTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let shortcut = KeyboardShortcutConfig.custom(
      keyCode: 35,
      modifiers: [.maskCommand, .maskAlternate],
      keyDisplay: "P"
    )

    KeyboardShortcutConfig.save(shortcut, to: defaults)

    #expect(KeyboardShortcutConfig.load(from: defaults) == shortcut)
    defaults.removePersistentDomain(forName: suiteName)
  }

  @Test func shortcutInvalidCustomConfigFallsBackToDefault() {
    let suiteName = "ShortcutTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(
      KeyboardShortcutConfig.customIdentifier, forKey: SettingsKey.globalShortcutIdentifier)
    defaults.set(35, forKey: SettingsKey.globalShortcutKeyCode)
    defaults.set(Int(CGEventFlags.maskShift.rawValue), forKey: SettingsKey.globalShortcutModifiers)
    defaults.set("⇧P", forKey: SettingsKey.globalShortcutDisplay)

    #expect(KeyboardShortcutConfig.load(from: defaults) == .defaultShortcut)
    defaults.removePersistentDomain(forName: suiteName)
  }

  @Test func shortcutCustomDisplayOrdersModifiersConsistently() {
    let shortcut = KeyboardShortcutConfig.custom(
      keyCode: 35,
      modifiers: [.maskCommand, .maskShift, .maskAlternate],
      keyDisplay: "P"
    )

    #expect(shortcut.display == "⌥⇧⌘P")
  }

  @Test func shortcutPresetsAreValid() {
    let allValid = KeyboardShortcutConfig.presets.allSatisfy { $0.isValid }
    #expect(allValid)
  }

  @Test func shortcutMatchesExactKeyAndModifiers() {
    let shortcut = KeyboardShortcutConfig.custom(
      keyCode: 35,
      modifiers: [.maskCommand, .maskAlternate],
      keyDisplay: "P"
    )

    #expect(shortcut.matches(keyCode: 35, flags: [.maskCommand, .maskAlternate]))
  }

  @Test func shortcutRejectsExtraShortcutModifiers() {
    let shortcut = KeyboardShortcutConfig.custom(
      keyCode: 35,
      modifiers: [.maskCommand, .maskAlternate],
      keyDisplay: "P"
    )

    #expect(!shortcut.matches(keyCode: 35, flags: [.maskCommand, .maskAlternate, .maskShift]))
  }

  @Test func shortcutRejectsWrongKeyCode() {
    let shortcut = KeyboardShortcutConfig.custom(
      keyCode: 35,
      modifiers: [.maskCommand, .maskAlternate],
      keyDisplay: "P"
    )

    #expect(!shortcut.matches(keyCode: 36, flags: [.maskCommand, .maskAlternate]))
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

  @Test func settingsMenuItemUsesVisibleSettingsLabel() {
    #expect(MenuBarController.settingsMenuItemTitle == "Settings…")
  }

  #if DEBUG
    @Test func handleQACopyFirstQueuedCaptureInvokesCallback() {
      let controller = MenuBarController()
      var called = false
      controller.onQACopyFirstQueuedCapture = { called = true }
      controller.perform(NSSelectorFromString("handleQACopyFirstQueuedCapture"))
      #expect(called == true)
    }

    @Test func handleQACopyFirstQueuedSubmitURLInvokesCallback() {
      let controller = MenuBarController()
      var called = false
      controller.onQACopyFirstQueuedSubmitURL = { called = true }
      controller.perform(NSSelectorFromString("handleQACopyFirstQueuedSubmitURL"))
      #expect(called == true)
    }

    @Test func handleQAMarkFirstQueuedCapturePostedInvokesCallback() {
      let controller = MenuBarController()
      var called = false
      controller.onQAMarkFirstQueuedCapturePosted = { called = true }
      controller.perform(NSSelectorFromString("handleQAMarkFirstQueuedCapturePosted"))
      #expect(called == true)
    }

    @Test func handleQACreateTestCaptureInvokesCallback() {
      let controller = MenuBarController()
      var called = false
      controller.onQACreateTestCapture = { called = true }
      controller.perform(NSSelectorFromString("handleQACreateTestCapture"))
      #expect(called == true)
    }

    @Test func handleQADeleteTestCapturesInvokesCallback() {
      let controller = MenuBarController()
      var called = false
      controller.onQADeleteTestCaptures = { called = true }
      controller.perform(NSSelectorFromString("handleQADeleteTestCaptures"))
      #expect(called == true)
    }

    @Test func handleQACopyFirstQueuedCaptureTitleInvokesCallback() {
      let controller = MenuBarController()
      var called = false
      controller.onQACopyFirstQueuedCaptureTitle = { called = true }
      controller.perform(NSSelectorFromString("handleQACopyFirstQueuedCaptureTitle"))
      #expect(called == true)
    }
  #endif

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
