# UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the floating NSPanel sidebar with a native macOS menu bar app — NSStatusItem + NSPopover + standalone windows — and strip all sticker styling in favor of Apple system design.

**Architecture:** Three surfaces (popover, capture window, preferences window) controlled by a MenuBarController that replaces PanelController. All views rewritten with system colors/fonts. Services and models untouched.

**Tech Stack:** Swift 6.0, SwiftUI, AppKit (NSStatusItem, NSPopover, NSWindow), SwiftData, macOS 14+

**Spec:** `docs/superpowers/specs/2026-04-27-ux-redesign-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `Sources/Services/MenuBarController.swift` | NSStatusItem, NSPopover, window lifecycle |
| `Sources/Views/PopoverContentView.swift` | Flat feed: event banner + capture cards |
| `Sources/Views/EventBannerView.swift` | Conditional upcoming-event banner |
| `Sources/Views/CaptureWindowView.swift` | Standalone capture/edit form |
| `Sources/Views/PreferencesView.swift` | Tab container for Channels/General/Notifications |
| `Sources/Views/GeneralTabView.swift` | General preferences tab |
| `Sources/Views/NotificationsTabView.swift` | Notifications preferences tab |
| `Tests/RedditReminderTests/MenuBarControllerTests.swift` | Tests for new controller |

### Files to Delete (after migration)
| File | Replaced By |
|------|------------|
| `Sources/Views/SidebarContainer.swift` | PopoverContentView |
| `Sources/Views/StripView.swift` | NSStatusItem in MenuBarController |
| `Sources/Views/GlanceView.swift` | EventBannerView + PopoverContentView |
| `Sources/Views/BrowseView.swift` | PopoverContentView |
| `Sources/Views/CalendarMonthView.swift` | (removed from scope) |
| `Sources/Views/CalendarTimelineView.swift` | (removed from scope) |
| `Sources/Views/ShortcutOnboardingCard.swift` | (cut — shortcut in Preferences) |
| `Sources/Utilities/StickerStyles.swift` | System styling inline |
| `Sources/Utilities/Constants.swift` | Inlined into MenuBarController |
| `Sources/Services/PanelController.swift` | MenuBarController |

### Files Modified In-Place
| File | Changes |
|------|---------|
| `Sources/App/AppDelegate.swift` | Replace PanelController with MenuBarController |
| `Sources/App/RedditReminderApp.swift` | Remove hidden window, simplify to MenuBarExtra or bare App |
| `Sources/Views/CaptureCardView.swift` | Restyle: system colors, remove sticker modifiers |
| `Sources/Views/LinkChipView.swift` | Restyle: system blue, remove bold border |
| `Sources/Views/SubredditRow.swift` | Restyle: system colors, remove sticker modifiers |
| `Sources/Views/ChannelsView.swift` | Restyle for Preferences context, rename to ChannelsTabView |
| `Sources/Views/SettingsView.swift` | Delete (replaced by GeneralTabView + NotificationsTabView) |
| `Sources/Views/EventCardView.swift` | Delete (replaced by EventBannerView) |
| `Tests/RedditReminderTests/PanelControllerTests.swift` | Delete (replaced by MenuBarControllerTests) |
| `Tests/RedditReminderTests/SidebarHeightTests.swift` | Delete (no sidebar heights) |

---

## Task 1: MenuBarController — Core Shell

Build the new controller that owns the NSStatusItem and NSPopover. No views yet — just the infrastructure.

**Files:**
- Create: `Sources/Services/MenuBarController.swift`
- Create: `Tests/RedditReminderTests/MenuBarControllerTests.swift`

- [ ] **Step 1: Write failing tests for MenuBarController**

```swift
// Tests/RedditReminderTests/MenuBarControllerTests.swift
import Testing
import Foundation
@testable import RedditReminder

@Suite(.serialized)
@MainActor
struct MenuBarControllerTests {
    @Test func initialBadgeCountIsZero() {
        let controller = MenuBarController()
        #expect(controller.badgeCount == 0)
    }

    @Test func settingBadgeCountUpdatesProperty() {
        let controller = MenuBarController()
        controller.badgeCount = 5
        #expect(controller.badgeCount == 5)
    }

    @Test func isUrgentDefaultsToFalse() {
        let controller = MenuBarController()
        #expect(controller.isUrgent == false)
    }

    @Test func settingIsUrgentUpdatesProperty() {
        let controller = MenuBarController()
        controller.isUrgent = true
        #expect(controller.isUrgent == true)
    }

    @Test func popoverIsNotVisibleByDefault() {
        let controller = MenuBarController()
        #expect(controller.isPopoverVisible == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `MenuBarController` not defined

- [ ] **Step 3: Write MenuBarController skeleton**

```swift
// Sources/Services/MenuBarController.swift
import AppKit
import SwiftUI

@MainActor
@Observable
final class MenuBarController {
    var badgeCount: Int = 0
    var isUrgent: Bool = false
    var isPopoverVisible: Bool = false

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var captureWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    func setup(popoverContent: some View) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "r.circle", accessibilityDescription: "RedditReminder")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 350, height: 480)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(rootView: popoverContent)

        self.statusItem = item
        self.popover = pop
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            isPopoverVisible = false
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            isPopoverVisible = true
        }
    }

    func showCaptureWindow(content: some View) {
        if let existing = captureWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "New Capture"
        window.center()
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        dismissPopover()
        self.captureWindow = window
    }

    func closeCaptureWindow() {
        captureWindow?.close()
        captureWindow = nil
    }

    func showPreferencesWindow(content: some View) {
        if let existing = preferencesWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RedditReminder Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        dismissPopover()
        self.preferencesWindow = window
    }

    func closePreferencesWindow() {
        preferencesWindow?.close()
        preferencesWindow = nil
    }

    func dismissPopover() {
        popover?.performClose(nil)
        isPopoverVisible = false
    }

    func updateIcon() {
        guard let button = statusItem?.button else { return }

        if isUrgent {
            let config = NSImage.SymbolConfiguration(
                paletteColors: [NSColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0)]
            )
            button.image = NSImage(
                systemSymbolName: "r.circle.fill",
                accessibilityDescription: "RedditReminder — urgent"
            )?.withSymbolConfiguration(config)
            button.image?.isTemplate = false
        } else {
            button.image = NSImage(
                systemSymbolName: "r.circle",
                accessibilityDescription: "RedditReminder"
            )
            button.image?.isTemplate = true
        }

        // Badge: use the button's title for count overlay
        if badgeCount > 0 {
            button.title = "\(badgeCount)"
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All 5 MenuBarControllerTests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/MenuBarController.swift Tests/RedditReminderTests/MenuBarControllerTests.swift
git commit -m "feat(ux): add MenuBarController shell with NSStatusItem and NSPopover"
```

---

## Task 2: Restyle CaptureCardView with System Design

Remove sticker modifiers from the capture card and switch to system styling. This card is reused by the popover feed.

**Files:**
- Modify: `Sources/Views/CaptureCardView.swift`

- [ ] **Step 1: Read the current CaptureCardView**

Read `Sources/Views/CaptureCardView.swift` to confirm current state.

- [ ] **Step 2: Rewrite CaptureCardView with system styling**

Replace the full contents of `Sources/Views/CaptureCardView.swift` with:

```swift
import SwiftUI
import SwiftData

struct CaptureCardView: View {
    let capture: Capture
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(capture.text)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if let sub = capture.subreddits.first {
                            Text(sub.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.0))
                        }

                        if !capture.links.isEmpty || !capture.mediaRefs.isEmpty || capture.notes != nil {
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(attachmentSummary)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                urgencyDot
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var urgencyDot: some View {
        let level = urgencyLevel
        if level == .high || level == .active {
            Circle()
                .fill(Color(red: 1.0, green: 0.27, blue: 0.0))
                .frame(width: 6, height: 6)
                .padding(.top, 5)
        } else if level == .medium {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
        }
    }

    private var urgencyLevel: UrgencyLevel {
        // Determine from associated events — simplified: check if any
        // subreddit has an upcoming event
        .none
    }

    private var attachmentSummary: String {
        var parts: [String] = []
        if !capture.links.isEmpty {
            parts.append("\(capture.links.count) link\(capture.links.count == 1 ? "" : "s")")
        }
        if !capture.mediaRefs.isEmpty {
            parts.append("\(capture.mediaRefs.count) image\(capture.mediaRefs.count == 1 ? "" : "s")")
        }
        if capture.notes != nil {
            parts.append("notes")
        }
        return parts.joined(separator: " · ")
    }
}
```

- [ ] **Step 3: Build to verify no compile errors**

Run: `make build`
Expected: BUILD SUCCEEDED (warnings about unused urgencyLevel are OK for now)

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/CaptureCardView.swift
git commit -m "feat(ux): restyle CaptureCardView with system colors and hairline layout"
```

---

## Task 3: Restyle LinkChipView with System Design

**Files:**
- Modify: `Sources/Views/LinkChipView.swift`

- [ ] **Step 1: Read the current LinkChipView**

Read `Sources/Views/LinkChipView.swift` to confirm current state.

- [ ] **Step 2: Rewrite LinkChipView with system styling**

Replace the full contents of `Sources/Views/LinkChipView.swift` with:

```swift
import SwiftUI

struct LinkChipView: View {
    let url: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: 9))
            Text(displayURL)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var displayURL: String {
        var display = url
        if display.hasPrefix("https://") { display = String(display.dropFirst(8)) }
        if display.hasPrefix("http://") { display = String(display.dropFirst(7)) }
        if display.hasPrefix("www.") { display = String(display.dropFirst(4)) }
        return display
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/LinkChipView.swift
git commit -m "feat(ux): restyle LinkChipView with system blue tint, remove bold border"
```

---

## Task 4: Restyle SubredditRow with System Design

**Files:**
- Modify: `Sources/Views/SubredditRow.swift`

- [ ] **Step 1: Read the current SubredditRow**

Read `Sources/Views/SubredditRow.swift` to confirm current state.

- [ ] **Step 2: Rewrite SubredditRow with system styling**

Replace the full contents of `Sources/Views/SubredditRow.swift` with:

```swift
import SwiftUI
import SwiftData

struct SubredditRow: View {
    @Bindable var sub: Subreddit
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    private static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(isExpanded ? Self.redditOrange : .secondary)
                        Text(sub.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    if isExpanded {
                        Button("Remove", action: onDelete)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                    } else {
                        Text(peakDaysSummary)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(10)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    Text("PEAK DAYS")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)
                    peakDayChips

                    Text("PEAK HOURS (UTC)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)
                    peakHourChips

                    HStack {
                        Spacer()
                        Button("Reset to defaults", action: resetDefaults)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .underline()
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Peak Day Chips

    private static let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    private var peakDayChips: some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(Self.allDays, Self.dayKeys)), id: \.0) { display, key in
                let isOn = sub.peakDaysOverride?.contains(key) ?? false
                Button(action: { toggleDay(key) }) {
                    Text(display)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isOn ? Self.redditOrange.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isOn ? Self.redditOrange : .separator, lineWidth: 0.5)
                        )
                        .foregroundStyle(isOn ? Self.redditOrange : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleDay(_ day: String) {
        var days = sub.peakDaysOverride ?? []
        if days.contains(day) {
            days.removeAll { $0 == day }
        } else {
            days.append(day)
        }
        sub.peakDaysOverride = days.isEmpty ? nil : days
    }

    // MARK: - Peak Hour Chips

    private static let displayHours = [0, 2, 4, 6, 8, 10, 12, 14, 15, 16, 17, 18, 20, 22]

    private var peakHourChips: some View {
        let columns = [GridItem(.adaptive(minimum: 30), spacing: 3)]
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Self.displayHours, id: \.self) { hour in
                let isOn = sub.peakHoursUtcOverride?.contains(hour) ?? false
                Button(action: { toggleHour(hour) }) {
                    Text("\(hour)")
                        .font(.system(size: 9, weight: .medium))
                        .frame(minWidth: 24)
                        .padding(.vertical, 3)
                        .background(isOn ? Color.green.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isOn ? Color.green : .separator, lineWidth: 0.5)
                        )
                        .foregroundStyle(isOn ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleHour(_ hour: Int) {
        var hours = sub.peakHoursUtcOverride ?? []
        if hours.contains(hour) {
            hours.removeAll { $0 == hour }
        } else {
            hours.append(hour)
            hours.sort()
        }
        sub.peakHoursUtcOverride = hours.isEmpty ? nil : hours
    }

    // MARK: - Helpers

    private var peakDaysSummary: String {
        guard let days = sub.peakDaysOverride, !days.isEmpty else { return "defaults" }
        return days.map { $0.prefix(3).capitalized }.joined(separator: " ")
    }

    private func resetDefaults() {
        sub.peakDaysOverride = nil
        sub.peakHoursUtcOverride = nil
    }
}

// MARK: - Drag & Drop

struct SubredditDropDelegate: DropDelegate {
    let target: Subreddit
    @Binding var dragging: Subreddit?
    let subreddits: [Subreddit]
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let source = dragging, source.id != target.id else { return }
        guard let fromIndex = subreddits.firstIndex(where: { $0.id == source.id }),
              let toIndex = subreddits.firstIndex(where: { $0.id == target.id }) else { return }

        var reordered = subreddits
        let item = reordered.remove(at: fromIndex)
        reordered.insert(item, at: toIndex)

        for (i, sub) in reordered.enumerated() {
            sub.sortOrder = i
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to save subreddit reorder: \(error)")
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/SubredditRow.swift
git commit -m "feat(ux): restyle SubredditRow with system colors, 0.5pt borders"
```

---

## Task 5: EventBannerView

Create the conditional event banner that replaces EventCardView and GlanceView's alert banner.

**Files:**
- Create: `Sources/Views/EventBannerView.swift`

- [ ] **Step 1: Create EventBannerView**

```swift
// Sources/Views/EventBannerView.swift
import SwiftUI

struct EventBannerView: View {
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    var onTap: ((TimingEngine.UpcomingWindow) -> Void)? = nil

    private static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)

    var body: some View {
        if let next = upcomingWindows.first {
            Button(action: { onTap?(next) }) {
                HStack(spacing: 0) {
                    // Orange left accent bar
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Self.redditOrange)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("UPCOMING")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Self.redditOrange)
                            .tracking(0.5)

                        if let sub = next.event.subreddit {
                            Text("\(sub.name) — \(next.event.name)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        } else {
                            Text(next.event.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 4) {
                            Text(relativeTime(next.eventDate))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            if next.matchingCaptureCount > 0 {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text("\(next.matchingCaptureCount) capture\(next.matchingCaptureCount == 1 ? "" : "s") ready")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            if upcomingWindows.count > 1 {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text("and \(upcomingWindows.count - 1) more")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Self.redditOrange)
                            }
                        }
                    }
                    .padding(.leading, 10)

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Self.redditOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/EventBannerView.swift
git commit -m "feat(ux): add EventBannerView for popover upcoming-event banner"
```

---

## Task 6: PopoverContentView — The Main Feed

The flat-feed popover view that replaces SidebarContainer, GlanceView, and BrowseView.

**Files:**
- Create: `Sources/Views/PopoverContentView.swift`

- [ ] **Step 1: Create PopoverContentView**

```swift
// Sources/Views/PopoverContentView.swift
import SwiftUI
import SwiftData

struct PopoverContentView: View {
    let menuBarController: MenuBarController
    let notificationService: NotificationService
    let onCaptureChanged: @MainActor () -> Void

    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query private var allEvents: [SubredditEvent]
    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]

    @Environment(\.modelContext) private var modelContext

    @State private var timingEngine = TimingEngine()

    private var activeEvents: [SubredditEvent] { allEvents.filter(\.isActive) }
    private var queuedCaptures: [Capture] { captures.filter { $0.status == .queued } }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Scrollable feed
            if queuedCaptures.isEmpty && timingEngine.upcomingWindows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        EventBannerView(
                            upcomingWindows: timingEngine.upcomingWindows
                        )

                        ForEach(queuedCaptures, id: \.id) { capture in
                            CaptureCardView(capture: capture, onTap: {
                                openCaptureForEditing(capture)
                            })

                            if capture.id != queuedCaptures.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }

            // Footer
            footer
        }
        .frame(width: 350)
        .onAppear {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
        .onChange(of: captures.count) {
            timingEngine.refresh(events: activeEvents, captures: captures)
            onCaptureChanged()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("RedditReminder")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: openPreferences) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: openNewCapture) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.0))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        let eventCount = timingEngine.upcomingWindows.count
        let captureCount = queuedCaptures.count

        return VStack(spacing: 0) {
            Divider()
            Text("\(captureCount) capture\(captureCount == 1 ? "" : "s") · \(eventCount) event\(eventCount == 1 ? "" : "s") upcoming")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No captures yet")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button("+ New Capture", action: openNewCapture)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.0))
                .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func openNewCapture() {
        let formView = CaptureWindowView(
            mode: .create,
            onSave: { result in
                saveCapture(result)
                menuBarController.closeCaptureWindow()
            },
            onCancel: {
                menuBarController.closeCaptureWindow()
            }
        )
        .modelContainer(modelContext.container)

        menuBarController.showCaptureWindow(content: formView)
    }

    private func openCaptureForEditing(_ capture: Capture) {
        let formView = CaptureWindowView(
            mode: .edit(capture),
            onSave: { result in
                updateCapture(capture, with: result)
                menuBarController.closeCaptureWindow()
            },
            onCancel: {
                menuBarController.closeCaptureWindow()
            }
        )
        .modelContainer(modelContext.container)

        menuBarController.showCaptureWindow(content: formView)
    }

    private func openPreferences() {
        let prefsView = PreferencesView(notificationService: notificationService)
            .modelContainer(modelContext.container)

        menuBarController.showPreferencesWindow(content: prefsView)
    }

    private func saveCapture(_ result: CaptureFormResult) {
        let capture = Capture(
            text: result.text,
            notes: result.notes,
            links: result.links,
            mediaRefs: result.mediaURLs.map(\.lastPathComponent),
            project: result.project,
            subreddits: result.subreddits
        )
        modelContext.insert(capture)
        try? modelContext.save()
    }

    private func updateCapture(_ capture: Capture, with result: CaptureFormResult) {
        capture.text = result.text
        capture.notes = result.notes
        capture.links = result.links
        capture.mediaRefs = result.mediaURLs.map(\.lastPathComponent)
        capture.project = result.project
        capture.subreddits = result.subreddits
        try? modelContext.save()
    }
}
```

- [ ] **Step 2: Build to verify (will fail — CaptureWindowView and PreferencesView don't exist yet)**

Run: `make build`
Expected: FAIL on missing `CaptureWindowView` and `PreferencesView` — that's OK, we create them in Tasks 7 and 8.

- [ ] **Step 3: Commit (even with build errors — this is the logical unit)**

```bash
git add Sources/Views/PopoverContentView.swift
git commit -m "feat(ux): add PopoverContentView flat-feed for menu bar popover"
```

---

## Task 7: CaptureWindowView — Standalone Capture Form

Rewrite the capture form for the standalone window. Supports create and edit modes.

**Files:**
- Create: `Sources/Views/CaptureWindowView.swift`

- [ ] **Step 1: Create CaptureWindowView**

```swift
// Sources/Views/CaptureWindowView.swift
import SwiftUI
import SwiftData

struct CaptureWindowView: View {
    enum Mode {
        case create
        case edit(Capture)
    }

    let mode: Mode
    let onSave: (CaptureFormResult) -> Void
    let onCancel: () -> Void

    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]

    @State private var text: String = ""
    @State private var notes: String = ""
    @State private var selectedProject: Project?
    @State private var selectedSubreddits: Set<UUID> = []
    @State private var links: [String] = []
    @State private var newLinkText: String = ""
    @State private var droppedFiles: [URL] = []
    @State private var isDragOver: Bool = false

    private static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Capture text
                    fieldSection("CAPTURE TEXT") {
                        TextEditor(text: $text)
                            .font(.system(size: 12))
                            .frame(minHeight: 72)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.separator, lineWidth: 0.5)
                            )
                    }

                    // Subreddit picker
                    fieldSection("SUBREDDIT") {
                        Menu {
                            ForEach(subreddits, id: \.id) { sub in
                                Button(action: {
                                    if selectedSubreddits.contains(sub.id) {
                                        selectedSubreddits.remove(sub.id)
                                    } else {
                                        selectedSubreddits.insert(sub.id)
                                    }
                                }) {
                                    HStack {
                                        Text(sub.name)
                                        if selectedSubreddits.contains(sub.id) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if selectedSubreddits.isEmpty {
                                    Text("Select subreddit...")
                                        .foregroundStyle(.secondary)
                                } else {
                                    let names = subreddits
                                        .filter { selectedSubreddits.contains($0.id) }
                                        .map(\.name)
                                        .joined(separator: ", ")
                                    Text(names)
                                        .foregroundStyle(Self.redditOrange)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 12))
                            .padding(8)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.separator, lineWidth: 0.5)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // Project picker
                    fieldSection("PROJECT", optional: true) {
                        Picker("", selection: $selectedProject) {
                            Text("None").tag(nil as Project?)
                            ForEach(projects.filter { !$0.archived }, id: \.id) { project in
                                Text(project.name).tag(project as Project?)
                            }
                        }
                        .labelsHidden()
                        .font(.system(size: 12))
                        .padding(4)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator, lineWidth: 0.5)
                        )
                    }

                    // Notes
                    fieldSection("NOTES", optional: true) {
                        TextField("Add context or reminders...", text: $notes)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.separator, lineWidth: 0.5)
                            )
                    }

                    // Links
                    fieldSection("LINKS") {
                        FlowLayout(spacing: 6) {
                            ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                                LinkChipView(url: link, onRemove: {
                                    links.remove(at: index)
                                })
                            }

                            HStack(spacing: 4) {
                                TextField("Add link...", text: $newLinkText)
                                    .font(.system(size: 10))
                                    .textFieldStyle(.plain)
                                    .frame(width: 120)
                                    .onSubmit { addLink() }

                                if !newLinkText.isEmpty {
                                    Button(action: addLink) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Self.redditOrange)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.separator, style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            )
                        }
                    }

                    // Media drop zone
                    fieldSection("MEDIA") {
                        VStack(spacing: 8) {
                            if !droppedFiles.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(Array(droppedFiles.enumerated()), id: \.offset) { index, url in
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc")
                                                .font(.system(size: 9))
                                            Text(url.lastPathComponent)
                                                .font(.system(size: 10))
                                                .lineLimit(1)
                                            Button(action: { droppedFiles.remove(at: index) }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 7, weight: .bold))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary.opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }

                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator, style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .frame(height: 48)
                                .overlay {
                                    Text("Drop images here or ")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    + Text("browse")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.blue)
                                }
                                .background(isDragOver ? Color.blue.opacity(0.05) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                                    for provider in providers {
                                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                            if let url {
                                                Task { @MainActor in
                                                    droppedFiles.append(url)
                                                }
                                            }
                                        }
                                    }
                                    return true
                                }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 420, height: 480)
        .onAppear { populateFromMode() }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Text(titleText)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button("Cancel", action: onCancel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

            Button("Save", action: save)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(canSave ? Self.redditOrange : Self.redditOrange.opacity(0.4))
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var titleText: String {
        switch mode {
        case .create: "New Capture"
        case .edit: "Edit Capture"
        }
    }

    // MARK: - Field Section Helper

    private func fieldSection<Content: View>(
        _ label: String,
        optional: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                if optional {
                    Text("(optional)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            content()
        }
    }

    // MARK: - Logic

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedSubreddits.isEmpty
    }

    private func save() {
        guard canSave else { return }
        let selectedSubs = subreddits.filter { selectedSubreddits.contains($0.id) }
        let result = CaptureFormResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes,
            links: links,
            project: selectedProject,
            subreddits: selectedSubs,
            mediaURLs: droppedFiles
        )
        onSave(result)
    }

    private func addLink() {
        let trimmed = newLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        links.append(url)
        newLinkText = ""
    }

    private func populateFromMode() {
        if case .edit(let capture) = mode {
            text = capture.text
            notes = capture.notes ?? ""
            selectedProject = capture.project
            selectedSubreddits = Set(capture.subreddits.map(\.id))
            links = capture.links
            // mediaRefs would need URL reconstruction — simplified for now
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED. Note: Project model uses `archived` (Bool), not `isArchived`. The filter `!($0.isArchived ?? false)` in the code above must be `!$0.archived`.

- [ ] **Step 3: Fix any compile errors and build again**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/CaptureWindowView.swift
git commit -m "feat(ux): add CaptureWindowView standalone capture form with FlowLayout"
```

---

## Task 8: PreferencesView — Channels, General, Notifications

Create the three-tab Preferences window that replaces ChannelsView and SettingsView.

**Files:**
- Create: `Sources/Views/PreferencesView.swift`
- Create: `Sources/Views/GeneralTabView.swift`
- Create: `Sources/Views/NotificationsTabView.swift`
- Modify: `Sources/Views/ChannelsView.swift` (restyle and rename content to work as a tab)

- [ ] **Step 1: Create GeneralTabView**

```swift
// Sources/Views/GeneralTabView.swift
import SwiftUI

struct GeneralTabView: View {
    @AppStorage("defaultLeadTimeMinutes") private var defaultLeadTimeMinutes: Int = 60

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                HStack {
                    Text("Toggle popover")
                        .font(.system(size: 12))
                    Spacer()
                    Text("⌘⇧R")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Defaults") {
                Picker("Default lead time", selection: $defaultLeadTimeMinutes) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
                .font(.system(size: 12))
            }

            Section("Menu Bar") {
                HStack {
                    Text("Icon style")
                        .font(.system(size: 12))
                    Spacer()
                    Text("R circle (default)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
```

- [ ] **Step 2: Create NotificationsTabView**

```swift
// Sources/Views/NotificationsTabView.swift
import SwiftUI

struct NotificationsTabView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("nudgeWhenEmpty") private var nudgeWhenEmpty: Bool = true
    @AppStorage("defaultLeadTimeMinutes") private var defaultLeadTimeMinutes: Int = 60

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable macOS notifications", isOn: $notificationsEnabled)
                    .font(.system(size: 12))

                if notificationsEnabled {
                    Picker("Remind me before events", selection: $defaultLeadTimeMinutes) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                    }
                    .font(.system(size: 12))

                    Toggle("Nudge when queue is empty", isOn: $nudgeWhenEmpty)
                        .font(.system(size: 12))
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
```

- [ ] **Step 3: Restyle ChannelsView for Preferences context**

Read `Sources/Views/ChannelsView.swift`, then replace its contents with:

```swift
// Sources/Views/ChannelsView.swift
import SwiftUI
import SwiftData

struct ChannelsTabView: View {
    let notificationService: NotificationService

    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]
    @Environment(\.modelContext) private var modelContext

    @State private var expandedSubredditId: UUID?
    @State private var newSubredditName = ""
    @State private var draggingSubreddit: Subreddit?

    var body: some View {
        VStack(spacing: 0) {
            // Add row
            HStack(spacing: 8) {
                TextField("Add subreddit...", text: $newSubredditName)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .padding(7)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 0.5)
                    )
                    .onSubmit { addSubreddit() }

                Button(action: addSubreddit) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(canAdd ? Color(red: 1.0, green: 0.27, blue: 0.0) : .secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            canAdd
                                ? Color(red: 1.0, green: 0.27, blue: 0.0).opacity(0.15)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
            .padding(12)

            Divider()

            // Subreddit list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(subreddits, id: \.id) { sub in
                        SubredditRow(
                            sub: sub,
                            isExpanded: expandedSubredditId == sub.id,
                            onToggle: { toggleExpanded(sub) },
                            onDelete: { deleteSubreddit(sub) }
                        )
                        .onDrag {
                            draggingSubreddit = sub
                            return NSItemProvider(object: sub.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: SubredditDropDelegate(
                            target: sub,
                            dragging: $draggingSubreddit,
                            subreddits: subreddits,
                            modelContext: modelContext
                        ))
                    }
                }
                .padding(12)
            }
        }
        .onDisappear { savePendingChanges() }
    }

    // MARK: - Logic

    private var canAdd: Bool {
        guard let name = normalizedSubredditName() else { return false }
        return !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() })
    }

    private func normalizedSubredditName() -> String? {
        let trimmed = newSubredditName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix("r/") ? trimmed : "r/\(trimmed)"
    }

    private func addSubreddit() {
        guard let name = normalizedSubredditName(), canAdd else { return }
        let nextOrder = (subreddits.map(\.sortOrder).max() ?? -1) + 1
        let sub = Subreddit(name: name, sortOrder: nextOrder)
        modelContext.insert(sub)
        try? modelContext.save()
        newSubredditName = ""
    }

    private func toggleExpanded(_ sub: Subreddit) {
        savePendingChanges()
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedSubredditId = expandedSubredditId == sub.id ? nil : sub.id
        }
    }

    private func savePendingChanges() {
        guard modelContext.hasChanges else { return }
        try? modelContext.save()
    }

    private func deleteSubreddit(_ sub: Subreddit) {
        for event in sub.events {
            notificationService.cancelNotifications(for: event.id)
        }
        modelContext.delete(sub)
        try? modelContext.save()
    }
}
```

- [ ] **Step 4: Create PreferencesView tab container**

```swift
// Sources/Views/PreferencesView.swift
import SwiftUI

struct PreferencesView: View {
    let notificationService: NotificationService

    @State private var selectedTab: Tab = .channels

    enum Tab: String, CaseIterable {
        case channels = "Channels"
        case general = "General"
        case notifications = "Notifications"
    }

    private static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar tabs
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundStyle(selectedTab == tab ? Self.redditOrange : .secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(
                                selectedTab == tab
                                    ? Self.redditOrange.opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.15))

            Divider()

            // Tab content
            switch selectedTab {
            case .channels:
                ChannelsTabView(notificationService: notificationService)
            case .general:
                GeneralTabView()
            case .notifications:
                NotificationsTabView()
            }
        }
        .frame(width: 500, height: 440)
    }
}
```

- [ ] **Step 5: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED (or minor issues from old references to `ChannelsView` — those will be cleaned up in Task 10)

- [ ] **Step 6: Commit**

```bash
git add Sources/Views/PreferencesView.swift Sources/Views/GeneralTabView.swift Sources/Views/NotificationsTabView.swift Sources/Views/ChannelsView.swift
git commit -m "feat(ux): add PreferencesView with Channels/General/Notifications tabs"
```

---

## Task 9: Wire Up AppDelegate and RedditReminderApp

Replace PanelController with MenuBarController in the app entry points.

**Files:**
- Modify: `Sources/App/AppDelegate.swift`
- Modify: `Sources/App/RedditReminderApp.swift`

- [ ] **Step 1: Read both files**

Read `Sources/App/AppDelegate.swift` and `Sources/App/RedditReminderApp.swift` to confirm current state.

- [ ] **Step 2: Rewrite AppDelegate**

Replace PanelController references with MenuBarController. The refresh cycle, notification scheduling, and global shortcut logic stay the same.

```swift
// Sources/App/AppDelegate.swift
// Replace line 6:
//   let panelController = PanelController()
// with:
//   let menuBarController = MenuBarController()
```

Full replacement — update the entire file to:

```swift
import AppKit
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()
    let timingEngine = TimingEngine()
    let notificationService = NotificationService()
    let heuristicsStore = HeuristicsStore()

    var modelContainer: ModelContainer?

    private let globalShortcut = GlobalShortcut()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        globalShortcut.register { [weak self] in
            self?.menuBarController.togglePopover()
        }

        Task {
            try? await notificationService.requestPermission()
        }

        startRefreshTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcut.unregister()
        refreshTimer?.invalidate()
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.runRefreshCycle()
            }
        }
    }

    func runRefreshCycle() {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)

        let events: [SubredditEvent]
        let captures: [Capture]
        do {
            events = try context.fetch(FetchDescriptor<SubredditEvent>())
            captures = try context.fetch(FetchDescriptor<Capture>())
        } catch {
            NSLog("RedditReminder: refresh fetch failed: \(error)")
            return
        }

        let activeEvents = events.filter(\.isActive)
        timingEngine.refresh(events: activeEvents, captures: captures)

        // Update menu bar icon state
        let queuedCount = captures.filter { $0.status == .queued }.count
        menuBarController.badgeCount = queuedCount
        menuBarController.isUrgent = timingEngine.upcomingWindows.contains { $0.urgency >= .high }
        menuBarController.updateIcon()

        Task {
            await scheduleNotifications(
                activeEvents: activeEvents,
                windows: timingEngine.upcomingWindows
            )
        }
    }

    private func scheduleNotifications(
        activeEvents: [SubredditEvent],
        windows: [TimingEngine.UpcomingWindow]
    ) async {
        let enabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        let nudge = UserDefaults.standard.bool(forKey: "nudgeWhenEmpty")
        guard enabled else { return }

        let permitted = await notificationService.isPermitted()
        guard permitted else { return }

        var scheduledCount = 0
        for window in windows {
            notificationService.scheduleWindowNotification(
                event: window.event,
                fireDate: window.notificationFireDate,
                matchingCaptureCount: window.matchingCaptureCount
            )
            scheduledCount += 1

            if nudge && window.matchingCaptureCount == 0 {
                notificationService.scheduleEmptyQueueNudge(
                    event: window.event,
                    fireDate: window.notificationFireDate.addingTimeInterval(-3600)
                )
            }
        }

        let activeIds = Set(activeEvents.map(\.id))
        let cancelCount = notificationService.cancelStaleNotifications(excluding: activeIds)
        NSLog("RedditReminder: scheduled \(scheduledCount) notifications, cancelled \(cancelCount) stale")
    }
}
```

- [ ] **Step 3: Add ⌘N and ⌘, menu items to AppDelegate**

Add a main menu with keyboard shortcuts. After the `startRefreshTimer()` call in `applicationDidFinishLaunching`, add:

```swift
// Add menu bar shortcuts
let mainMenu = NSMenu()

let appMenu = NSMenu()
appMenu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
appMenu.addItem(NSMenuItem.separator())
appMenu.addItem(NSMenuItem(title: "Quit RedditReminder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
let appMenuItem = NSMenuItem()
appMenuItem.submenu = appMenu
mainMenu.addItem(appMenuItem)

let fileMenu = NSMenu(title: "File")
fileMenu.addItem(NSMenuItem(title: "New Capture", action: #selector(openNewCapture), keyEquivalent: "n"))
let fileMenuItem = NSMenuItem()
fileMenuItem.submenu = fileMenu
mainMenu.addItem(fileMenuItem)

NSApplication.shared.mainMenu = mainMenu
```

And add the handler methods:

```swift
@objc func openPreferences() {
    // Preferences window creation delegated to PopoverContentView
    // which has access to the model container. Post a notification.
    NotificationCenter.default.post(name: .openPreferences, object: nil)
}

@objc func openNewCapture() {
    NotificationCenter.default.post(name: .openNewCapture, object: nil)
}
```

Add notification name extensions at file scope:

```swift
extension Notification.Name {
    static let openPreferences = Notification.Name("RedditReminder.openPreferences")
    static let openNewCapture = Notification.Name("RedditReminder.openNewCapture")
}
```

Then in PopoverContentView (Task 6), add `.onReceive` handlers to respond to these notifications and open the appropriate windows. This keeps the model container access in the view layer where SwiftData is available.

- [ ] **Step 4: Rewrite RedditReminderApp**

Replace the hidden window approach. The menu bar controller setup happens in `applicationDidFinishLaunching` or `onAppear`.

```swift
// Sources/App/RedditReminderApp.swift
import SwiftUI
import SwiftData

@main
struct RedditReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer

    init() {
        let schema = Schema([Project.self, Capture.self, Subreddit.self, SubredditEvent.self])
        container = try! ModelContainer(for: schema)
    }

    var body: some Scene {
        WindowGroup("RedditReminderKeepalive") {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    appDelegate.modelContainer = container

                    let context = ModelContext(container)
                    DefaultSubreddits.seedIfEmpty(context: context)

                    appDelegate.runRefreshCycle()

                    let popoverContent = PopoverContentView(
                        menuBarController: appDelegate.menuBarController,
                        notificationService: appDelegate.notificationService,
                        onCaptureChanged: { [weak appDelegate] in
                            appDelegate?.runRefreshCycle()
                        }
                    )
                    .modelContainer(container)

                    appDelegate.menuBarController.setup(popoverContent: popoverContent)
                }
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
    }
}
```

- [ ] **Step 5: Build to verify**

Run: `make build`
Expected: BUILD SUCCEEDED (may have warnings about old references — the deleted files haven't been removed yet, but they're no longer imported)

- [ ] **Step 6: Commit**

```bash
git add Sources/App/AppDelegate.swift Sources/App/RedditReminderApp.swift
git commit -m "feat(ux): wire MenuBarController into AppDelegate and app entry point"
```

---

## Task 10: Delete Old Files

Remove all files that are no longer needed.

**Files:**
- Delete: `Sources/Views/SidebarContainer.swift`
- Delete: `Sources/Views/StripView.swift`
- Delete: `Sources/Views/GlanceView.swift`
- Delete: `Sources/Views/BrowseView.swift`
- Delete: `Sources/Views/CalendarMonthView.swift`
- Delete: `Sources/Views/CalendarTimelineView.swift`
- Delete: `Sources/Views/ShortcutOnboardingCard.swift`
- Delete: `Sources/Views/EventCardView.swift`
- Delete: `Sources/Views/SettingsView.swift`
- Delete: `Sources/Views/CaptureFormView.swift`
- Delete: `Sources/Utilities/StickerStyles.swift`
- Delete: `Sources/Utilities/Constants.swift`
- Delete: `Sources/Services/PanelController.swift`
- Delete: `Tests/RedditReminderTests/PanelControllerTests.swift`
- Delete: `Tests/RedditReminderTests/SidebarHeightTests.swift`

- [ ] **Step 1: Delete old view files**

```bash
git rm Sources/Views/SidebarContainer.swift \
      Sources/Views/StripView.swift \
      Sources/Views/GlanceView.swift \
      Sources/Views/BrowseView.swift \
      Sources/Views/CalendarMonthView.swift \
      Sources/Views/CalendarTimelineView.swift \
      Sources/Views/ShortcutOnboardingCard.swift \
      Sources/Views/EventCardView.swift \
      Sources/Views/SettingsView.swift \
      Sources/Views/CaptureFormView.swift
```

- [ ] **Step 2: Delete old utility and service files**

```bash
git rm Sources/Utilities/StickerStyles.swift \
      Sources/Utilities/Constants.swift \
      Sources/Services/PanelController.swift
```

- [ ] **Step 3: Delete old test files**

```bash
git rm Tests/RedditReminderTests/PanelControllerTests.swift \
      Tests/RedditReminderTests/SidebarHeightTests.swift
```

- [ ] **Step 4: Build to check for dangling references**

Run: `make build`
Expected: May fail with references to deleted types. Fix any remaining references (see Step 5).

- [ ] **Step 5: Fix compile errors from dangling references**

Search for remaining references to deleted types and fix them:
- `StickerColors.*` → replace with system colors or inline `Color(red:green:blue:)` for reddit orange
- `SidebarState` → should be gone from all new code
- `PanelController` → should be gone from all new code
- `stickerCard()`, `stickerButton()`, `stickerBadge()`, `stickerInput()` → remove modifier calls
- `stickerSectionLabel()` → replace with inline `Text().font().foregroundStyle()`
- `StickerDivider()` → replace with `Divider()`
- `UrgencyLevel` → move the enum definition to a new location if it was only in Constants.swift

Check if `UrgencyLevel` is defined only in `Constants.swift`. If so, extract it to its own file:

```swift
// Sources/Models/UrgencyLevel.swift
import SwiftUI

enum UrgencyLevel: Comparable {
    case none, low, medium, high, active, expired
}
```

Also extract `AppColors` and `MediaConstants` if needed:

```swift
// Sources/Utilities/AppColors.swift
import AppKit

enum AppColors {
    static let reddit = NSColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0)
    static let green = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
    static let blue = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1.0)
    static let purple = NSColor(red: 0.54, green: 0.17, blue: 0.89, alpha: 1.0)
    static let gold = NSColor(red: 0.81, green: 0.60, blue: 0.03, alpha: 1.0)
    static let pink = NSColor(red: 0.93, green: 0.29, blue: 0.60, alpha: 1.0)
}

enum MediaConstants {
    static let thumbnailMaxSize: Int = 200
    static let supportedImageTypes = ["png", "jpg", "jpeg", "gif"]
    static let supportedVideoTypes = ["mp4", "mov"]
}
```

- [ ] **Step 6: Build to verify clean compile**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(ux): delete old sidebar views, sticker styles, and panel controller"
```

---

## Task 11: Fix Tests

Update remaining tests that reference deleted types.

**Files:**
- Modify: Various test files that reference `SidebarState`, `StickerColors`, or `PanelController`

- [ ] **Step 1: Run tests to see what fails**

Run: `make test`
Expected: Some test files may fail to compile due to references to deleted types.

- [ ] **Step 2: Fix each failing test file**

For each compile error:
- `SidebarState` references → delete the test or rewrite for new architecture
- `PanelController` references → already deleted the test file in Task 10
- `SidebarHeightTests` → already deleted in Task 10
- `StickerColors` references → replace with system color equivalents

Check `ChannelsStateTests.swift` — if it references `ChannelsView`, update to `ChannelsTabView`.

- [ ] **Step 3: Run tests again**

Run: `make test`
Expected: ALL TESTS PASS

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test(ux): fix tests for menu bar popover architecture"
```

---

## Task 12: Make togglePopover Public and Verify Full Build

The `GlobalShortcut` handler in AppDelegate calls `menuBarController.togglePopover()`, but that method is currently marked `@objc private`. Make it accessible.

**Files:**
- Modify: `Sources/Services/MenuBarController.swift`

- [ ] **Step 1: Read MenuBarController and verify togglePopover visibility**

Read `Sources/Services/MenuBarController.swift`. The `togglePopover()` method needs to be callable both from the NSStatusItem button action (requires `@objc`) and from AppDelegate (requires non-private).

- [ ] **Step 2: Split into public API and private @objc target**

```swift
// In MenuBarController.swift, replace:
//   @objc private func togglePopover() {
// with:

func togglePopover() {
    guard let popover, let button = statusItem?.button else { return }

    if popover.isShown {
        popover.performClose(nil)
        isPopoverVisible = false
    } else {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverVisible = true
    }
}

// And update setup() to use a closure-based action instead of @objc selector:
```

In `setup(popoverContent:)`, replace the button action with:

```swift
if let button = item.button {
    button.image = NSImage(systemSymbolName: "r.circle", accessibilityDescription: "RedditReminder")
    button.image?.isTemplate = true
    button.target = self
    button.action = #selector(statusItemClicked)
}
```

And add:

```swift
@objc private func statusItemClicked() {
    togglePopover()
}
```

- [ ] **Step 3: Full build + test**

Run: `make test`
Expected: BUILD SUCCEEDED, ALL TESTS PASS

- [ ] **Step 4: Commit**

```bash
git add Sources/Services/MenuBarController.swift
git commit -m "fix(ux): make togglePopover public for global shortcut handler"
```

---

## Task 13: Smoke Test — Install and Verify

Run the full app and verify all three surfaces work.

**Files:** None (testing only)

- [ ] **Step 1: Install and launch**

Run: `make install`
Expected: App installs to ~/Applications and launches

- [ ] **Step 2: Verify menu bar icon appears**

Check that the "R" circle icon appears in the menu bar.

- [ ] **Step 3: Click icon — verify popover opens**

Click the menu bar icon. Verify:
- Popover appears below the icon
- Header shows "RedditReminder" with gear and "+" buttons
- If captures exist, they show as cards with system styling
- If no captures, shows "No captures yet" empty state
- Footer shows correct counts

- [ ] **Step 4: Click "+" — verify capture window opens**

Click the "+" button. Verify:
- Standalone window opens centered on screen
- Popover dismisses
- Form shows all fields: text, subreddit, project, notes, links, media
- Cancel closes window
- Save (with valid data) creates capture and closes window

- [ ] **Step 5: Click gear — verify preferences window opens**

Reopen popover, click gear. Verify:
- Preferences window opens
- Three tabs: Channels, General, Notifications
- Channels tab shows subreddit list with expandable rows
- Can add/remove subreddits
- General and Notifications tabs show their settings

- [ ] **Step 6: Verify ⌘⇧R shortcut still works**

Press ⌘⇧R. Verify popover toggles open/closed.

- [ ] **Step 7: Commit final state if any fixes were needed**

```bash
git add -A
git commit -m "fix(ux): smoke test fixes for menu bar popover"
```
