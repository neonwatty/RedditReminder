import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalShortcut {
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var tapThread: Thread?
  private var tapRunLoop: CFRunLoop?
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

    // Run the event tap on a dedicated background thread to avoid
    // blocking the main thread on every system-wide keystroke.
    let thread = Thread { [weak self] in
      guard let source = self?.runLoopSource else { return }
      let rl = CFRunLoopGetCurrent()
      self?.tapRunLoop = rl
      CFRunLoopAddSource(rl, source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
      CFRunLoopRun()
    }
    thread.name = "RedditReminder.EventTap"
    thread.qualityOfService = .userInteractive
    thread.start()
    tapThread = thread
  }

  func unregister() {
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    if let rl = tapRunLoop {
      CFRunLoopStop(rl)
    }
    tapThread?.cancel()
    eventTap = nil
    runLoopSource = nil
    tapRunLoop = nil
    tapThread = nil
    handler = nil
  }

  private nonisolated func handleEvent(
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
