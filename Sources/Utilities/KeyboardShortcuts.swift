@preconcurrency import CoreFoundation
import AppKit
import Carbon.HIToolbox
import os

@MainActor
final class GlobalShortcut {
  private var eventTap: CFMachPort?
  private var tapThread: Thread?

  private struct TapState: Sendable {
    var runLoopSource: CFRunLoopSource?
    var tapRunLoop: CFRunLoop?
    var handler: (@Sendable () -> Void)?
  }

  private let state = OSAllocatedUnfairLock(initialState: TapState())

  func register(handler: @escaping @Sendable () -> Void) {
    state.withLock { $0.handler = handler }

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

    let isCmd = flags.contains(.maskCommand)
    let isShift = flags.contains(.maskShift)
    let isR = keyCode == 15

    if isCmd && isShift && isR {
      let handler = state.withLock { $0.handler }
      if let handler {
        Task { @MainActor in handler() }
      }
      return nil  // consume the event
    }

    return Unmanaged.passRetained(event)
  }
}
