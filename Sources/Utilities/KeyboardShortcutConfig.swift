@preconcurrency import CoreFoundation
import Carbon.HIToolbox

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
    } else {
      defaults.removeObject(forKey: SettingsKey.globalShortcutKeyCode)
      defaults.removeObject(forKey: SettingsKey.globalShortcutModifiers)
      defaults.removeObject(forKey: SettingsKey.globalShortcutDisplay)
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

  func matches(keyCode candidateKeyCode: Int64, flags: CGEventFlags) -> Bool {
    candidateKeyCode == keyCode && Self.normalized(flags) == modifiers
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
