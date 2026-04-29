@preconcurrency import CoreFoundation
import AppKit
import os

@MainActor
protocol GlobalShortcutRegistering: AnyObject {
  func register(config: KeyboardShortcutConfig, handler: @escaping @Sendable () -> Void) -> Bool
  func unregister()
}

@MainActor
final class GlobalShortcut: GlobalShortcutRegistering {
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
    unregister()
    guard config.isValid else {
      NSLog("RedditReminder: invalid shortcut config \(config.identifier)")
      return false
    }
    state.withLock {
      $0.handler = handler
      $0.config = config
    }

    let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
    let callback: CGEventTapCallBack = { proxy, type, event, refcon in
      guard let refcon else { return Unmanaged.passUnretained(event) }
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
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }

    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    let config = state.withLock { $0.config }
    if config.matches(keyCode: keyCode, flags: flags) {
      let handler = state.withLock { $0.handler }
      if let handler {
        Task { @MainActor in handler() }
      }
      return nil  // consume the event
    }

    return Unmanaged.passUnretained(event)
  }
}
