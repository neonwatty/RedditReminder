import Foundation
import Testing
@testable import RedditReminder

@Test func backupSettingsSnapshotReadsAllBackedUpDefaults() {
    withTemporaryDefaults { defaults in
        defaults.set("project-id", forKey: SettingsKey.defaultProjectId)
        defaults.set(15, forKey: SettingsKey.defaultLeadTimeMinutes)
        defaults.set(false, forKey: SettingsKey.notificationsEnabled)
        defaults.set(true, forKey: SettingsKey.nudgeWhenEmpty)
        defaults.set(KeyboardShortcutConfig.customIdentifier, forKey: SettingsKey.globalShortcutIdentifier)
        defaults.set(31, forKey: SettingsKey.globalShortcutKeyCode)
        defaults.set(786432, forKey: SettingsKey.globalShortcutModifiers)
        defaults.set("Command Shift R", forKey: SettingsKey.globalShortcutDisplay)

        let settings = BackupSettingsPersistence.snapshot(from: defaults)

        #expect(settings.defaultProjectId == "project-id")
        #expect(settings.defaultLeadTimeMinutes == 15)
        #expect(settings.notificationsEnabled == false)
        #expect(settings.nudgeWhenEmpty == true)
        #expect(settings.globalShortcutIdentifier == KeyboardShortcutConfig.customIdentifier)
        #expect(settings.globalShortcutKeyCode == 31)
        #expect(settings.globalShortcutModifiers == 786432)
        #expect(settings.globalShortcutDisplay == "Command Shift R")
    }
}

@Test func backupSettingsApplyClearsOmittedDefaults() {
    withTemporaryDefaults { defaults in
        defaults.set("stale-project", forKey: SettingsKey.defaultProjectId)
        defaults.set(120, forKey: SettingsKey.defaultLeadTimeMinutes)
        defaults.set(false, forKey: SettingsKey.notificationsEnabled)
        defaults.set(true, forKey: SettingsKey.nudgeWhenEmpty)
        defaults.set("cmd-option-r", forKey: SettingsKey.globalShortcutIdentifier)
        defaults.set(15, forKey: SettingsKey.globalShortcutKeyCode)
        defaults.set(123, forKey: SettingsKey.globalShortcutModifiers)
        defaults.set("Old", forKey: SettingsKey.globalShortcutDisplay)

        BackupSettingsPersistence.apply(BackupSettings(), to: defaults)

        #expect(defaults.object(forKey: SettingsKey.defaultProjectId) == nil)
        #expect(defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) == nil)
        #expect(defaults.object(forKey: SettingsKey.notificationsEnabled) == nil)
        #expect(defaults.object(forKey: SettingsKey.nudgeWhenEmpty) == nil)
        #expect(defaults.object(forKey: SettingsKey.globalShortcutIdentifier) == nil)
        #expect(defaults.object(forKey: SettingsKey.globalShortcutKeyCode) == nil)
        #expect(defaults.object(forKey: SettingsKey.globalShortcutModifiers) == nil)
        #expect(defaults.object(forKey: SettingsKey.globalShortcutDisplay) == nil)
    }
}

@Test func backupSettingsApplyWritesFalseAndShortcutValues() {
    withTemporaryDefaults { defaults in
        let settings = BackupSettings(
            defaultProjectId: "project-id",
            defaultLeadTimeMinutes: 0,
            notificationsEnabled: false,
            nudgeWhenEmpty: false,
            globalShortcutIdentifier: KeyboardShortcutConfig.customIdentifier,
            globalShortcutKeyCode: 31,
            globalShortcutModifiers: 786432,
            globalShortcutDisplay: "Command Shift R"
        )

        BackupSettingsPersistence.apply(settings, to: defaults)

        #expect(defaults.string(forKey: SettingsKey.defaultProjectId) == "project-id")
        #expect(defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int == 0)
        #expect(defaults.object(forKey: SettingsKey.notificationsEnabled) as? Bool == false)
        #expect(defaults.object(forKey: SettingsKey.nudgeWhenEmpty) as? Bool == false)
        #expect(defaults.string(forKey: SettingsKey.globalShortcutIdentifier) == KeyboardShortcutConfig.customIdentifier)
        #expect(defaults.object(forKey: SettingsKey.globalShortcutKeyCode) as? Int == 31)
        #expect(defaults.object(forKey: SettingsKey.globalShortcutModifiers) as? Int == 786432)
        #expect(defaults.string(forKey: SettingsKey.globalShortcutDisplay) == "Command Shift R")
    }
}

private func withTemporaryDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "BackupSettingsPersistenceTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    body(defaults)
}
