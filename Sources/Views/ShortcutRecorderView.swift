import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderView: View {
  @Binding var config: KeyboardShortcutConfig

  @State private var isRecording = false
  @State private var validationMessage: String?

  var body: some View {
    VStack(alignment: .trailing, spacing: 6) {
      HStack {
        Text("Toggle popover")
          .font(.system(size: 12))
        Spacer()
        Button(isRecording ? "Press shortcut" : config.display) {
          validationMessage = nil
          isRecording.toggle()
        }
        .font(.system(size: 12))
        .monospacedDigit()
        .frame(minWidth: 116)

        Button("Reset") {
          validationMessage = nil
          isRecording = false
          config = .defaultShortcut
        }
        .font(.system(size: 11))
      }

      if let validationMessage {
        Text(validationMessage)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
    }
    .background {
      if isRecording {
        ShortcutKeyCaptureView { event in
          record(event)
        }
        .frame(width: 0, height: 0)
      }
    }
  }

  private func record(_ event: NSEvent) {
    guard event.keyCode != UInt16(kVK_Escape) else {
      isRecording = false
      validationMessage = nil
      return
    }

    let keyDisplay = Self.keyDisplay(for: event)
    let next = KeyboardShortcutConfig.custom(
      keyCode: Int64(event.keyCode),
      modifiers: event.modifierFlags.cgEventFlags,
      keyDisplay: keyDisplay
    )

    guard next.isValid else {
      validationMessage = "Use Command, Control, or Option with a key."
      return
    }

    config = next
    validationMessage = nil
    isRecording = false
  }

  private static func keyDisplay(for event: NSEvent) -> String {
    if let special = specialKeyDisplay[event.keyCode] {
      return special
    }

    let characters = event.charactersIgnoringModifiers?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .uppercased()
    return characters?.isEmpty == false ? characters! : "Key \(event.keyCode)"
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

private struct ShortcutKeyCaptureView: NSViewRepresentable {
  let onKeyDown: (NSEvent) -> Void

  func makeNSView(context: Context) -> KeyCaptureNSView {
    KeyCaptureNSView(onKeyDown: onKeyDown)
  }

  func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
    nsView.onKeyDown = onKeyDown
    nsView.window?.makeFirstResponder(nsView)
  }

  final class KeyCaptureNSView: NSView {
    var onKeyDown: (NSEvent) -> Void

    init(onKeyDown: @escaping (NSEvent) -> Void) {
      self.onKeyDown = onKeyDown
      super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
      nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
      onKeyDown(event)
    }
  }
}

extension NSEvent.ModifierFlags {
  fileprivate var cgEventFlags: CGEventFlags {
    var flags: CGEventFlags = []
    if contains(.command) { flags.insert(.maskCommand) }
    if contains(.control) { flags.insert(.maskControl) }
    if contains(.option) { flags.insert(.maskAlternate) }
    if contains(.shift) { flags.insert(.maskShift) }
    return flags
  }
}
