import Foundation

enum BackupSettingsPersistence {
    static func snapshot(from defaults: UserDefaults) -> BackupSettings {
        BackupSettings(
            defaultProjectId: defaults.string(forKey: SettingsKey.defaultProjectId),
            defaultLeadTimeMinutes: defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int,
            notificationsEnabled: defaults.object(forKey: SettingsKey.notificationsEnabled) as? Bool,
            nudgeWhenEmpty: defaults.object(forKey: SettingsKey.nudgeWhenEmpty) as? Bool,
            globalShortcutIdentifier: defaults.string(forKey: SettingsKey.globalShortcutIdentifier),
            globalShortcutKeyCode: defaults.object(forKey: SettingsKey.globalShortcutKeyCode) as? Int,
            globalShortcutModifiers: defaults.object(forKey: SettingsKey.globalShortcutModifiers) as? Int,
            globalShortcutDisplay: defaults.string(forKey: SettingsKey.globalShortcutDisplay)
        )
    }

    static func apply(_ settings: BackupSettings, to defaults: UserDefaults) {
        set(settings.defaultProjectId, forKey: SettingsKey.defaultProjectId, defaults: defaults)
        set(settings.defaultLeadTimeMinutes, forKey: SettingsKey.defaultLeadTimeMinutes, defaults: defaults)
        set(settings.notificationsEnabled, forKey: SettingsKey.notificationsEnabled, defaults: defaults)
        set(settings.nudgeWhenEmpty, forKey: SettingsKey.nudgeWhenEmpty, defaults: defaults)
        set(settings.globalShortcutIdentifier, forKey: SettingsKey.globalShortcutIdentifier, defaults: defaults)
        set(settings.globalShortcutKeyCode, forKey: SettingsKey.globalShortcutKeyCode, defaults: defaults)
        set(settings.globalShortcutModifiers, forKey: SettingsKey.globalShortcutModifiers, defaults: defaults)
        set(settings.globalShortcutDisplay, forKey: SettingsKey.globalShortcutDisplay, defaults: defaults)
    }

    private static func set(_ value: Any?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
