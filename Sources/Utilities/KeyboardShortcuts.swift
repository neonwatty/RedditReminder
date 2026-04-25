import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalShortcut {
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var handler: (() -> Void)?

  func register(handler: @escaping () -> Void) {
    self.handler = handler

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
      return
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  func unregister() {
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
    eventTap = nil
    runLoopSource = nil
    handler = nil
  }

  private func handleEvent(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    let isCmd = flags.contains(.maskCommand)
    let isShift = flags.contains(.maskShift)
    let isR = keyCode == 15

    if isCmd && isShift && isR {
      Task { @MainActor in
        self.handler?()
      }
      return nil  // consume the event
    }

    return Unmanaged.passRetained(event)
  }
}
