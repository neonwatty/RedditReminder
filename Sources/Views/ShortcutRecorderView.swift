import AppKit
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
    let keyDisplay = ShortcutRecorderInput.keyDisplay(
      keyCode: event.keyCode,
      charactersIgnoringModifiers: event.charactersIgnoringModifiers
    )
    switch ShortcutRecorderInput.evaluate(
      keyCode: event.keyCode,
      modifiers: event.modifierFlags.cgEventFlags,
      keyDisplay: keyDisplay
    ) {
    case .cancelled:
      isRecording = false
      validationMessage = nil
    case let .invalid(message):
      validationMessage = message
    case let .shortcut(next):
      config = next
      validationMessage = nil
      isRecording = false
    }
  }
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
