import Testing
import Foundation
import AppKit
import UserNotifications
@testable import RedditReminder

private struct ShortcutTemporaryDefaults {
    let defaults: UserDefaults
    let suiteName: String

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class ShortcutNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {}
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    func removeAllPendingNotificationRequests() {}
    func getAuthorizationStatus() async -> UNAuthorizationStatus { .authorized }
}

@MainActor
private final class RecordingGlobalShortcut: GlobalShortcutRegistering {
    var registerResults = [true]
    private(set) var registeredConfigs: [KeyboardShortcutConfig] = []
    private(set) var unregisterCount = 0

    func register(config: KeyboardShortcutConfig, handler: @escaping @Sendable () -> Void) -> Bool {
        registeredConfigs.append(config)
        return registerResults.isEmpty ? true : registerResults.removeFirst()
    }

    func unregister() {
        unregisterCount += 1
    }
}

@Test @MainActor func appDelegateRegistersShortcutFromInjectedDefaults() {
    let temporaryDefaults = makeShortcutDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    let shortcut = KeyboardShortcutConfig.presets[1]
    KeyboardShortcutConfig.save(shortcut, to: defaults)
    let globalShortcut = RecordingGlobalShortcut()
    let delegate = makeShortcutDelegate(defaults: defaults, globalShortcut: globalShortcut)

    delegate.registerGlobalShortcut()

    #expect(globalShortcut.registeredConfigs == [shortcut])
}

@Test @MainActor func appDelegateDoesNotRegisterUnchangedShortcutTwice() {
    let temporaryDefaults = makeShortcutDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    let globalShortcut = RecordingGlobalShortcut()
    let delegate = makeShortcutDelegate(defaults: defaults, globalShortcut: globalShortcut)

    delegate.registerGlobalShortcut()
    delegate.registerGlobalShortcut()

    #expect(globalShortcut.registeredConfigs == [.defaultShortcut])
}

@Test @MainActor func appDelegateRetriesShortcutAfterFailedRegistration() {
    let temporaryDefaults = makeShortcutDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    let globalShortcut = RecordingGlobalShortcut()
    globalShortcut.registerResults = [false, true]
    let delegate = makeShortcutDelegate(defaults: defaults, globalShortcut: globalShortcut)

    delegate.registerGlobalShortcut()
    delegate.registerGlobalShortcut()

    #expect(globalShortcut.registeredConfigs == [.defaultShortcut, .defaultShortcut])
}

@Test @MainActor func appDelegateUnregistersShortcutOnTerminate() {
    let temporaryDefaults = makeShortcutDefaults()
    let defaults = temporaryDefaults.defaults
    defer { temporaryDefaults.cleanup() }
    let globalShortcut = RecordingGlobalShortcut()
    let delegate = makeShortcutDelegate(defaults: defaults, globalShortcut: globalShortcut)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

    #expect(globalShortcut.unregisterCount == 1)
}

private func makeShortcutDefaults() -> ShortcutTemporaryDefaults {
    let suiteName = "AppDelegateShortcutTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return ShortcutTemporaryDefaults(defaults: defaults, suiteName: suiteName)
}

@MainActor
private func makeShortcutDelegate(
    defaults: UserDefaults,
    globalShortcut: RecordingGlobalShortcut
) -> AppDelegate {
    AppDelegate(
        menuBarController: MenuBarController(),
        timingEngine: TimingEngine(),
        notificationService: NotificationService(center: ShortcutNotificationCenter()),
        heuristicsStore: HeuristicsStore(bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false),
        defaults: defaults,
        globalShortcut: globalShortcut
    )
}
