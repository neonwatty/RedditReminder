import Foundation

extension AppDelegate {
    func registerGlobalShortcut() {
        let config = KeyboardShortcutConfig.load(from: defaults)
        guard config != activeShortcutConfig else { return }
        let registered = globalShortcut.register(config: config) { [weak self] in
            MainActor.assumeIsolated {
                self?.menuBarController.togglePopover()
            }
        }
        if registered {
            defaults.set(false, forKey: SettingsKey.globalShortcutRegistrationFailed)
            activeShortcutConfig = config
            NSLog("RedditReminder: \(config.display) registered")
        } else {
            defaults.set(true, forKey: SettingsKey.globalShortcutRegistrationFailed)
            activeShortcutConfig = nil
        }
    }
}
