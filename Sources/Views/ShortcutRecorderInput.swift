@preconcurrency import CoreFoundation
import Carbon.HIToolbox
import Foundation

struct ShortcutRecorderInput {
  enum Result: Equatable {
    case cancelled
    case invalid(String)
    case shortcut(KeyboardShortcutConfig)
  }

  nonisolated static let validationMessage = "Use Command, Control, or Option with a key."

  static func evaluate(keyCode: UInt16, modifiers: CGEventFlags, keyDisplay: String) -> Result {
    guard keyCode != UInt16(kVK_Escape) else { return .cancelled }

    let config = KeyboardShortcutConfig.custom(
      keyCode: Int64(keyCode),
      modifiers: modifiers,
      keyDisplay: keyDisplay
    )
    return config.isValid ? .shortcut(config) : .invalid(validationMessage)
  }

  static func keyDisplay(keyCode: UInt16, charactersIgnoringModifiers: String?) -> String {
    if let special = specialKeyDisplay[keyCode] {
      return special
    }

    let characters = charactersIgnoringModifiers?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .uppercased()
    return characters?.isEmpty == false ? characters! : "Key \(keyCode)"
  }

  private static let specialKeyDisplay: [UInt16: String] = [
    UInt16(kVK_Space): "Space",
    UInt16(kVK_Return): "Return",
    UInt16(kVK_Tab): "Tab",
    UInt16(kVK_Delete): "Delete",
    UInt16(kVK_ForwardDelete): "Forward Delete",
    UInt16(kVK_Escape): "Escape",
    UInt16(kVK_LeftArrow): "←",
    UInt16(kVK_RightArrow): "→",
    UInt16(kVK_UpArrow): "↑",
    UInt16(kVK_DownArrow): "↓",
    UInt16(kVK_F1): "F1",
    UInt16(kVK_F2): "F2",
    UInt16(kVK_F3): "F3",
    UInt16(kVK_F4): "F4",
    UInt16(kVK_F5): "F5",
    UInt16(kVK_F6): "F6",
    UInt16(kVK_F7): "F7",
    UInt16(kVK_F8): "F8",
    UInt16(kVK_F9): "F9",
    UInt16(kVK_F10): "F10",
    UInt16(kVK_F11): "F11",
    UInt16(kVK_F12): "F12",
  ]
}
