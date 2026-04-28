@preconcurrency import CoreFoundation
import AppKit
import Carbon.HIToolbox
import os

struct KeyboardShortcutConfig: Equatable, Sendable {
  static let customIdentifier = "custom"

  let identifier: String
  let keyCode: Int64
  let modifiers: CGEventFlags
  let display: String

  var isValid: Bool {
    keyCode >= 0 && Self.requiredModifierMasks.contains { modifiers.contains($0) }
  }

  static let defaultShortcut = KeyboardShortcutConfig(
    identifier: "cmd-shift-r",
    keyCode: Int64(kVK_ANSI_R),
    modifiers: [.maskCommand, .maskShift],
    display: "⌘⇧R"
  )

  static let presets: [KeyboardShortcutConfig] = [
    defaultShortcut,
    KeyboardShortcutConfig(
      identifier: "cmd-option-r",
      keyCode: Int64(kVK_ANSI_R),
      modifiers: [.maskCommand, .maskAlternate],
      display: "⌘⌥R"
    ),
    KeyboardShortcutConfig(
      identifier: "ctrl-option-r",
      keyCode: Int64(kVK_ANSI_R),
      modifiers: [.maskControl, .maskAlternate],
      display: "⌃⌥R"
    ),
    KeyboardShortcutConfig(
      identifier: "cmd-shift-space",
      keyCode: Int64(kVK_Space),
      modifiers: [.maskCommand, .maskShift],
      display: "⌘⇧Space"
    )
  ]

  static func load(from defaults: UserDefaults = .standard) -> KeyboardShortcutConfig {
    let identifier = defaults.string(forKey: SettingsKey.globalShortcutIdentifier)
      ?? defaultShortcut.identifier
    if identifier == customIdentifier,
       defaults.object(forKey: SettingsKey.globalShortcutKeyCode) != nil,
       defaults.object(forKey: SettingsKey.globalShortcutModifiers) != nil {
      let config = KeyboardShortcutConfig(
        identifier: customIdentifier,
        keyCode: Int64(defaults.integer(forKey: SettingsKey.globalShortcutKeyCode)),
        modifiers: CGEventFlags(rawValue: UInt64(defaults.integer(forKey: SettingsKey.globalShortcutModifiers))),
        display: defaults.string(forKey: SettingsKey.globalShortcutDisplay) ?? "Custom"
      )
      return config.isValid ? config : defaultShortcut
    }
    return presets.first { $0.identifier == identifier && $0.isValid } ?? defaultShortcut
  }

  static func save(_ config: KeyboardShortcutConfig, to defaults: UserDefaults = .standard) {
    if config.identifier == customIdentifier {
      defaults.set(Int(config.keyCode), forKey: SettingsKey.globalShortcutKeyCode)
      defaults.set(Int(config.modifiers.rawValue), forKey: SettingsKey.globalShortcutModifiers)
      defaults.set(config.display, forKey: SettingsKey.globalShortcutDisplay)
    }
    defaults.set(config.identifier, forKey: SettingsKey.globalShortcutIdentifier)
  }

  static func custom(keyCode: Int64, modifiers: CGEventFlags, keyDisplay: String) -> KeyboardShortcutConfig {
    KeyboardShortcutConfig(
      identifier: customIdentifier,
      keyCode: keyCode,
      modifiers: normalized(modifiers),
      display: display(modifiers: modifiers, key: keyDisplay)
    )
  }

  static func display(modifiers: CGEventFlags, key: String) -> String {
    "\(modifierDisplay(for: normalized(modifiers)))\(key)"
  }

  private static func normalized(_ modifiers: CGEventFlags) -> CGEventFlags {
    var normalized: CGEventFlags = []
    for mask in allModifierMasks where modifiers.contains(mask) {
      normalized.insert(mask)
    }
    return normalized
  }

  private static func modifierDisplay(for modifiers: CGEventFlags) -> String {
    var parts: [String] = []
    if modifiers.contains(.maskControl) { parts.append("⌃") }
    if modifiers.contains(.maskAlternate) { parts.append("⌥") }
    if modifiers.contains(.maskShift) { parts.append("⇧") }
    if modifiers.contains(.maskCommand) { parts.append("⌘") }
    return parts.joined()
  }

  private static let requiredModifierMasks: [CGEventFlags] = [
    .maskCommand,
    .maskControl,
    .maskAlternate
  ]

  private static let allModifierMasks: [CGEventFlags] = [
    .maskCommand,
    .maskControl,
    .maskAlternate,
    .maskShift
  ]
}

@MainActor
final class GlobalShortcut {
  private var eventTap: CFMachPort?
  private var tapThread: Thread?

  private struct TapState: Sendable {
    var runLoopSource: CFRunLoopSource?
    var tapRunLoop: CFRunLoop?
    var handler: (@Sendable () -> Void)?
    var config: KeyboardShortcutConfig = .defaultShortcut
  }

  private let state = OSAllocatedUnfairLock(initialState: TapState())

  @discardableResult
  func register(
    config: KeyboardShortcutConfig = .defaultShortcut,
    handler: @escaping @Sendable () -> Void
  ) -> Bool {
    guard config.isValid else {
      NSLog("RedditReminder: invalid shortcut config \(config.identifier)")
      return false
    }
    unregister()
    state.withLock {
      $0.handler = handler
      $0.config = config
    }

    let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
    let callback: CGEventTapCallBack = { proxy, type, event, refcon in
      guard let refcon else { return Unmanaged.passRetained(event) }
      let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(refcon).takeUnretainedValue()
      return shortcut.handleEvent(proxy: proxy, type: type, event: event)
    }

    let refcon = Unmanaged.passUnretained(self).toOpaque()

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: refcon
      )
    else {
      NSLog("RedditReminder: failed to create event tap — grant Accessibility permission")
      state.withLock {
        $0.handler = nil
        $0.config = .defaultShortcut
      }
      return false
    }

    eventTap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    state.withLock { $0.runLoopSource = source }

    let thread = Thread { [state] in
      guard let source else { return }
      let rl = CFRunLoopGetCurrent()
      state.withLock { $0.tapRunLoop = rl }
      CFRunLoopAddSource(rl, source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
      CFRunLoopRun()
    }
    thread.name = "RedditReminder.EventTap"
    thread.qualityOfService = .userInteractive
    thread.start()
    tapThread = thread
    return true
  }

  func unregister() {
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    let rl = state.withLock { $0.tapRunLoop }
    if let rl {
      CFRunLoopStop(rl)
    }
    tapThread?.cancel()
    eventTap = nil
    state.withLock {
      $0.runLoopSource = nil
      $0.tapRunLoop = nil
      $0.handler = nil
    }
    tapThread = nil
  }

  private nonisolated func handleEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    let config = state.withLock { $0.config }
    if keyCode == config.keyCode && flags.contains(config.modifiers) {
      let handler = state.withLock { $0.handler }
      if let handler {
        Task { @MainActor in handler() }
      }
      return nil  // consume the event
    }

    return Unmanaged.passRetained(event)
  }
}
