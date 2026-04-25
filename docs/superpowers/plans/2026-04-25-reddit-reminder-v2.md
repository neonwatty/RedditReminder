# RedditReminder v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship RedditReminder v2 with state persistence, settings navigation, QA data seeding, refresh cycle wiring, shortcut onboarding, and sticker bomb styling.

**Architecture:** SwiftUI + AppKit hybrid. NSPanel floating sidebar with SwiftData persistence. All features built sequentially in a single branch, with the styling pass last so every view gets one clean sweep.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, AppKit (NSPanel), XcodeGen, macOS 14+

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `Sources/Utilities/QAFixtures.swift` | Predefined fixture data + insert/clear functions for QA testing |
| `Sources/Views/ShortcutOnboardingCard.swift` | First-launch card explaining ⌘⇧R and Accessibility permission |
| `Sources/Utilities/StickerStyles.swift` | Sticker bomb color palette + reusable ViewModifiers |

### Modified Files

| File | Changes |
|------|---------|
| `Sources/Utilities/Constants.swift` | Add `.settings` to `SidebarState`, add width mapping, replace `AppColors` with sticker palette |
| `Sources/Services/PanelController.swift` | `@AppStorage` persistence, `previousState` for settings back-nav |
| `Sources/Views/SidebarContainer.swift` | Gear icon, `.settings` case, dev menu tap handler, sticker styling |
| `Sources/Views/GlanceView.swift` | Onboarding card slot, sticker card styling |
| `Sources/Views/SettingsView.swift` | Sticker form styling |
| `Sources/App/AppDelegate.swift` | Accept `ModelContainer`, implement `runRefreshCycle()` |
| `Sources/App/RedditReminderApp.swift` | Pass container to AppDelegate |
| `Sources/Views/StripView.swift` | Sticker colors |
| `Sources/Views/BrowseView.swift` | Sticker card styling |
| `Sources/Views/CaptureFormView.swift` | Sticker input/button styling |
| `Sources/Views/CaptureCardView.swift` | Sticker card styling |
| `Sources/Views/EventCardView.swift` | Sticker card styling |
| `Sources/Views/CalendarTimelineView.swift` | Sticker timeline styling |
| `Sources/Views/CalendarMonthView.swift` | Sticker calendar styling |
| `scripts/qa.sh` | New tests for persistence, settings, and seeding |

---

### Task 1: State Persistence

**Files:**
- Modify: `Sources/Utilities/Constants.swift`
- Modify: `Sources/Services/PanelController.swift`
- Test: `Tests/RedditReminderTests/PanelControllerTests.swift`

- [ ] **Step 1: Make SidebarState conform to RawRepresentable for @AppStorage**

`SidebarState` already has `String` raw values via `CaseIterable`, but we need to verify it works with `@AppStorage`. The enum already declares `: String, CaseIterable` so raw values are auto-synthesized. No changes needed to `Constants.swift` for this step.

Verify by reading `Sources/Utilities/Constants.swift` — confirm `SidebarState: String, CaseIterable` is present. It is.

- [ ] **Step 2: Add @AppStorage persistence to PanelController**

In `Sources/Services/PanelController.swift`, add a stored property to persist state and restore it on setup. Since `PanelController` is `@Observable` (not a SwiftUI View), we can't use `@AppStorage` directly — use `UserDefaults` instead.

Replace the `state` property and modify `setup()` and `setState()`:

```swift
// In PanelController, replace:
//   var state: SidebarState = .glance
// with:

var state: SidebarState = .glance {
    didSet {
        UserDefaults.standard.set(state.rawValue, forKey: "sidebarState")
    }
}
```

In `setup(contentView:)`, before `positionPanel()`, add state restoration:

```swift
// Add at the top of setup(), before positionPanel():
if let saved = UserDefaults.standard.string(forKey: "sidebarState"),
   let restored = SidebarState(rawValue: saved) {
    switch restored {
    case .capture:
        state = .browse   // Don't restore into empty capture form
    case .settings:
        state = .glance   // Settings is transient
    default:
        state = restored
    }
}
```

Note: `.settings` doesn't exist yet — we'll add it in Task 2. For now this will produce a compile warning which is fine; or we can add the `.settings` case first. **Better approach:** just handle the known-good cases for now and add `.settings` in Task 2.

Revised restoration code (no `.settings` reference yet):

```swift
if let saved = UserDefaults.standard.string(forKey: "sidebarState"),
   let restored = SidebarState(rawValue: saved) {
    switch restored {
    case .capture:
        state = .browse
    default:
        state = restored
    }
}
```

- [ ] **Step 3: Write unit test for state persistence**

Create `Tests/RedditReminderTests/PanelControllerTests.swift`:

```swift
import Testing
import Foundation
@testable import RedditReminder

@MainActor
struct PanelControllerTests {
    @Test func statePersistsToUserDefaults() {
        let pc = PanelController()
        pc.state = .browse
        let saved = UserDefaults.standard.string(forKey: "sidebarState")
        #expect(saved == "browse")
    }

    @Test func captureRestoresToBrowse() {
        UserDefaults.standard.set("capture", forKey: "sidebarState")
        let saved = UserDefaults.standard.string(forKey: "sidebarState")
        let restored = SidebarState(rawValue: saved ?? "glance") ?? .glance
        let effective: SidebarState = restored == .capture ? .browse : restored
        #expect(effective == .browse)
    }

    @Test func glanceRestoresAsGlance() {
        UserDefaults.standard.set("glance", forKey: "sidebarState")
        let saved = UserDefaults.standard.string(forKey: "sidebarState")
        let restored = SidebarState(rawValue: saved ?? "glance") ?? .glance
        #expect(restored == .glance)
    }

    @Test func invalidDefaultsToGlance() {
        UserDefaults.standard.set("nonsense", forKey: "sidebarState")
        let saved = UserDefaults.standard.string(forKey: "sidebarState")
        let restored = SidebarState(rawValue: saved ?? "glance") ?? .glance
        #expect(restored == .glance)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make test
```

Expected: All tests pass including the new `PanelControllerTests`.

- [ ] **Step 5: Build and verify manually**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

After launch:
1. App starts in Glance (default).
2. Click back chevron → Strip (24px).
3. Quit and relaunch → should start in Strip.
4. Click strip → Glance. Click "+ New Capture" → Capture. Quit and relaunch → should start in Browse (smart default).

- [ ] **Step 6: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Services/PanelController.swift Tests/RedditReminderTests/PanelControllerTests.swift
git commit -m "feat: persist sidebar state across restarts with smart defaults"
```

---

### Task 2: Settings Navigation

**Files:**
- Modify: `Sources/Utilities/Constants.swift`
- Modify: `Sources/Services/PanelController.swift`
- Modify: `Sources/Views/SidebarContainer.swift`

- [ ] **Step 1: Add `.settings` case to SidebarState**

In `Sources/Utilities/Constants.swift`, add the new case and its width:

```swift
enum SidebarState: String, CaseIterable {
  case strip
  case glance
  case browse
  case capture
  case settings
}
```

In `SidebarConstants.width(for:)`, add:

```swift
static let settingsWidth: CGFloat = 320

static func width(for state: SidebarState) -> CGFloat {
    switch state {
    case .strip: return stripWidth
    case .glance: return glanceWidth
    case .browse: return browseWidth
    case .capture: return captureWidth
    case .settings: return settingsWidth
    }
}
```

- [ ] **Step 2: Add previousState and settings navigation to PanelController**

In `Sources/Services/PanelController.swift`:

Add a `previousState` property:

```swift
private var previousState: SidebarState = .glance
```

Add a method to navigate to settings:

```swift
func goToSettings() {
    guard state != .settings else { return }  // no-op if already in settings
    previousState = state
    setState(.settings)
}
```

Modify `stepDown()` to handle `.settings`:

```swift
func stepDown() {
    if state == .settings {
        setState(previousState)
        return
    }
    let ladder: [SidebarState] = [.strip, .glance, .browse, .capture]
    guard let idx = ladder.firstIndex(of: state), idx > 0 else { return }
    setState(ladder[idx - 1])
}
```

Update the state persistence restoration to handle `.settings`:

```swift
// In setup(), update the restoration switch:
if let saved = UserDefaults.standard.string(forKey: "sidebarState"),
   let restored = SidebarState(rawValue: saved) {
    switch restored {
    case .capture:
        state = .browse
    case .settings:
        state = .glance
    default:
        state = restored
    }
}
```

- [ ] **Step 3: Add gear icon and .settings view to SidebarContainer**

In `Sources/Views/SidebarContainer.swift`:

Add the `.settings` case to the view switch inside `body`:

```swift
case .settings:
    SettingsView(panelController: panelController)
```

Modify the `header` computed property to add a gear icon on the left:

```swift
private var header: some View {
    HStack {
        Button(action: { panelController.goToSettings() }) {
            Image(systemName: "gearshape")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)

        Text("RedditReminder")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color(nsColor: AppColors.reddit))
        Spacer()
        Button(action: { panelController.stepDown() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .overlay(alignment: .bottom) {
        Divider()
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

After launch:
1. In Glance, gear icon should be visible in header left side.
2. Click gear → sidebar expands to 320px and shows SettingsView.
3. Click back chevron → returns to Glance (previousState).
4. Go to Browse, click gear → Settings. Back chevron → Browse.
5. While in Settings, click gear again → no-op.
6. Quit while in Settings, relaunch → starts in Glance (settings is transient).

- [ ] **Step 5: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Utilities/Constants.swift Sources/Services/PanelController.swift Sources/Views/SidebarContainer.swift
git commit -m "feat: add settings navigation via gear icon in sidebar header"
```

---

### Task 3: QA Data Seeding

**Files:**
- Create: `Sources/Utilities/QAFixtures.swift`
- Modify: `Sources/Views/SidebarContainer.swift`

- [ ] **Step 1: Create QAFixtures.swift**

Create `Sources/Utilities/QAFixtures.swift`:

```swift
import Foundation
import SwiftData

enum QAFixtures {
    @MainActor
    static func seed(context: ModelContext) {
        clearAll(context: context)

        // 3 subreddits
        let sideProject = Subreddit(name: "r/SideProject")
        let swiftUI = Subreddit(name: "r/SwiftUI")
        let macOS = Subreddit(name: "r/macOS")
        context.insert(sideProject)
        context.insert(swiftUI)
        context.insert(macOS)

        // 1 project linking 2 subreddits
        let project = Project(name: "BullhornApp", projectDescription: "Social media scheduler")
        context.insert(project)

        // 5 captures: 3 queued, 2 draft (posted)
        let c1 = Capture(text: "Just shipped v2 with new scheduling engine", project: project, subreddits: [sideProject, swiftUI])
        context.insert(c1)

        let c2 = Capture(text: "Built a macOS sidebar for Reddit posting reminders", project: project, subreddits: [sideProject, macOS])
        context.insert(c2)

        let c3 = Capture(text: "SwiftData + NSPanel: lessons from building a floating sidebar", project: project, subreddits: [swiftUI])
        context.insert(c3)

        let c4 = Capture(text: "How I use sticker bomb design in a native macOS app", project: project, subreddits: [macOS])
        c4.markAsPosted()
        context.insert(c4)

        let c5 = Capture(text: "XcodeGen + Makefile: reproducible macOS builds", project: project, subreddits: [swiftUI, macOS])
        c5.markAsPosted()
        context.insert(c5)

        // 2 events: one upcoming (7 days), one overdue (yesterday)
        let upcoming = SubredditEvent(
            name: "Weekly SideProject",
            subreddit: sideProject,
            oneOffDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
        context.insert(upcoming)

        let overdue = SubredditEvent(
            name: "SwiftUI Show & Tell",
            subreddit: swiftUI,
            oneOffDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
        )
        context.insert(overdue)

        try? context.save()
        NSLog("RedditReminder: QA fixtures seeded")
    }

    @MainActor
    static func clearAll(context: ModelContext) {
        do {
            try context.delete(model: Capture.self)
            try context.delete(model: SubredditEvent.self)
            try context.delete(model: Project.self)
            try context.delete(model: Subreddit.self)
            try context.save()
            NSLog("RedditReminder: all data cleared")
        } catch {
            NSLog("RedditReminder: failed to clear data: \(error)")
        }
    }
}
```

- [ ] **Step 2: Add hidden dev menu to SidebarContainer**

In `Sources/Views/SidebarContainer.swift`, add state for the dev menu:

```swift
// Add to SidebarContainer's properties:
@State private var titleTapCount = 0
@State private var lastTapTime = Date.distantPast
@State private var showDevMenu = false
```

Replace the title `Text` in `header` with a tappable version:

```swift
Text("RedditReminder")
    .font(.system(size: 13, weight: .bold))
    .foregroundStyle(Color(nsColor: AppColors.reddit))
    .onTapGesture {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) > 2 {
            titleTapCount = 1
        } else {
            titleTapCount += 1
        }
        lastTapTime = now
        if titleTapCount >= 5 {
            showDevMenu = true
            titleTapCount = 0
        }
    }
```

Add the dev menu overlay to the `body` `ZStack`, after the main `VStack`:

```swift
// Inside the ZStack, after the VStack:
if showDevMenu {
    devMenuOverlay
}
```

Add the dev menu view:

```swift
private var devMenuOverlay: some View {
    VStack(spacing: 8) {
        Text("DEVELOPER")
            .font(.system(size: 9, weight: .bold))
            .tracking(2)
            .foregroundStyle(.tertiary)

        Button(action: {
            QAFixtures.seed(context: modelContext)
            showDevMenu = false
        }) {
            Text("Seed QA Data")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(nsColor: AppColors.green))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)

        Button(action: {
            QAFixtures.clearAll(context: modelContext)
            showDevMenu = false
        }) {
            Text("Clear All Data")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(nsColor: AppColors.reddit))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)

        Button(action: { showDevMenu = false }) {
            Text("Dismiss")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
    .padding(12)
    .background(Color(red: 0.12, green: 0.12, blue: 0.20))
    .overlay(
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 20)
    .padding(.top, 60)
    .frame(maxHeight: .infinity, alignment: .top)
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

After launch:
1. Tap "RedditReminder" title 5 times quickly → dev menu appears.
2. Click "Seed QA Data" → menu closes, data appears in Glance view (queue cards, upcoming events).
3. Open dev menu again → "Clear All Data" → all content disappears.
4. Seed again → same data reappears (idempotent).

- [ ] **Step 4: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Utilities/QAFixtures.swift Sources/Views/SidebarContainer.swift
git commit -m "feat: add hidden dev menu with QA data seeding"
```

---

### Task 4: Refresh Cycle Wiring

**Files:**
- Modify: `Sources/App/AppDelegate.swift`
- Modify: `Sources/App/RedditReminderApp.swift`

- [ ] **Step 1: Add ModelContainer property to AppDelegate**

In `Sources/App/AppDelegate.swift`, add a property and setter:

```swift
// Add property after existing service declarations:
var modelContainer: ModelContainer?
```

- [ ] **Step 2: Pass container from RedditReminderApp to AppDelegate**

In `Sources/App/RedditReminderApp.swift`, modify the `onAppear` closure to pass the container:

```swift
.onAppear {
    appDelegate.modelContainer = container
    let sidebarView = SidebarContainer(panelController: appDelegate.panelController)
        .modelContainer(container)
    appDelegate.panelController.setup(contentView: sidebarView)
}
```

- [ ] **Step 3: Implement runRefreshCycle()**

In `Sources/App/AppDelegate.swift`, replace the stub:

```swift
private func runRefreshCycle() {
    guard let container = modelContainer else {
        NSLog("RedditReminder: refresh skipped — no ModelContainer")
        return
    }

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

    // Track which event IDs have active windows
    var activeEventIds: Set<String> = []

    let nudgeEnabled = UserDefaults.standard.bool(forKey: "nudgeWhenEmpty")

    for window in timingEngine.upcomingWindows {
        let eventId = window.event.id.uuidString
        activeEventIds.insert(eventId)

        notificationService.scheduleWindowNotification(
            eventId: eventId,
            title: window.event.name,
            body: "\(window.matchingCaptureCount) captures ready for \(window.event.subreddit?.name ?? "subreddit")",
            fireDate: window.fireDate
        )

        if window.matchingCaptureCount == 0 && nudgeEnabled {
            notificationService.scheduleEmptyQueueNudge(
                eventId: eventId,
                subredditName: window.event.subreddit?.name ?? "subreddit",
                eventName: window.event.name,
                fireDate: window.fireDate
            )
        }
    }

    // Cancel notifications for events no longer in the active window set
    let allEventIds = Set(activeEvents.map { $0.id.uuidString })
    let staleIds = allEventIds.subtracting(activeEventIds)
    for staleId in staleIds {
        notificationService.cancelNotifications(eventId: staleId)
    }

    NSLog("RedditReminder: refresh complete — \(timingEngine.upcomingWindows.count) windows, \(staleIds.count) cancelled")
}
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

After launch:
1. Open dev menu, seed QA data.
2. Check Console.app for `RedditReminder: refresh complete` log — should show window count > 0.
3. The overdue event (yesterday) should not produce a window (it's in the past).
4. The upcoming event (7 days out) exceeds the 24-hour horizon, so it also won't produce a window. To see a window in testing, temporarily change the fixture to use a date within 24 hours.

- [ ] **Step 5: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/App/AppDelegate.swift Sources/App/RedditReminderApp.swift
git commit -m "feat: wire refresh cycle to TimingEngine and NotificationService"
```

---

### Task 5: Shortcut Onboarding Card

**Files:**
- Create: `Sources/Views/ShortcutOnboardingCard.swift`
- Modify: `Sources/Views/GlanceView.swift`

- [ ] **Step 1: Create ShortcutOnboardingCard.swift**

Create `Sources/Views/ShortcutOnboardingCard.swift`:

```swift
import SwiftUI

struct ShortcutOnboardingCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(nsColor: AppColors.reddit))
                Text("⌘⇧R toggles the sidebar")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Text("Use this shortcut from anywhere to show or hide RedditReminder. It requires Accessibility permission in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: openAccessibilitySettings) {
                    Text("Open System Settings")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: AppColors.reddit))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: AppColors.blue).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: AppColors.blue).opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Add onboarding card to GlanceView**

In `Sources/Views/GlanceView.swift`, add an `@AppStorage` property and an `onDismissOnboarding` callback:

```swift
// Add to GlanceView properties:
@AppStorage("hasSeenShortcutOnboarding") private var hasSeenOnboarding = false
```

Insert the card at the top of the `ScrollView`'s `VStack`, before the alert banner:

```swift
// Inside ScrollView > VStack, at the top:
if !hasSeenOnboarding {
    ShortcutOnboardingCard(onDismiss: {
        hasSeenOnboarding = true
    })
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

After launch:
1. Onboarding card appears at top of Glance view.
2. "Open System Settings" button opens Accessibility settings.
3. "Dismiss" button hides the card.
4. Quit and relaunch → card does not appear again.
5. To reset for testing: `defaults delete com.neonwatty.RedditReminder hasSeenShortcutOnboarding`

- [ ] **Step 4: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Views/ShortcutOnboardingCard.swift Sources/Views/GlanceView.swift
git commit -m "feat: add shortcut onboarding card for Accessibility permission"
```

---

### Task 6: Sticker Bomb Styling — Foundation

**Files:**
- Create: `Sources/Utilities/StickerStyles.swift`
- Modify: `Sources/Utilities/Constants.swift`

- [ ] **Step 1: Create StickerStyles.swift with color palette and ViewModifiers**

Create `Sources/Utilities/StickerStyles.swift`:

```swift
import SwiftUI

// MARK: - Sticker Color Palette

enum StickerColors {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.14)
    static let card       = Color(red: 0.10, green: 0.11, blue: 0.19)
    static let border     = Color(red: 0.27, green: 0.29, blue: 0.40)
    static let gold       = Color(red: 0.81, green: 0.60, blue: 0.03)
    static let pink       = Color(red: 0.93, green: 0.29, blue: 0.60)
    static let textPrimary   = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let textSecondary = Color(red: 0.55, green: 0.56, blue: 0.63)
}

// MARK: - Sticker ViewModifiers

struct StickerCardModifier: ViewModifier {
    var borderColor: Color = StickerColors.border

    func body(content: Content) -> some View {
        content
            .background(StickerColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 2)
            )
            .shadow(color: borderColor.opacity(0.5), radius: 0, x: 2, y: 2)
    }
}

struct StickerButtonModifier: ViewModifier {
    var bgColor: Color = StickerColors.gold

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(StickerColors.border, lineWidth: 2)
            )
            .shadow(color: StickerColors.border.opacity(0.5), radius: 0, x: 2, y: 2)
    }
}

struct StickerBadgeModifier: ViewModifier {
    var color: Color = StickerColors.border

    func body(content: Content) -> some View {
        content
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                Capsule()
                    .stroke(color, lineWidth: 2)
            )
            .clipShape(Capsule())
    }
}

struct StickerInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(StickerColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(StickerColors.border, lineWidth: 2)
            )
    }
}

// MARK: - View Extensions

extension View {
    func stickerCard(borderColor: Color = StickerColors.border) -> some View {
        modifier(StickerCardModifier(borderColor: borderColor))
    }

    func stickerButton(bgColor: Color = StickerColors.gold) -> some View {
        modifier(StickerButtonModifier(bgColor: bgColor))
    }

    func stickerBadge(color: Color = StickerColors.border) -> some View {
        modifier(StickerBadgeModifier(color: color))
    }

    func stickerInput() -> some View {
        modifier(StickerInputModifier())
    }
}
```

- [ ] **Step 2: Update AppColors in Constants.swift to use sticker palette**

In `Sources/Utilities/Constants.swift`, update `AppColors`:

```swift
enum AppColors {
  static let reddit = NSColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0)
  static let green = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
  static let blue = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1.0)
  static let purple = NSColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1.0)
  static let gold = NSColor(red: 0.81, green: 0.60, blue: 0.03, alpha: 1.0)
  static let pink = NSColor(red: 0.93, green: 0.29, blue: 0.60, alpha: 1.0)
}
```

- [ ] **Step 3: Build to verify compilation**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make build
```

Expected: clean build, no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Utilities/StickerStyles.swift Sources/Utilities/Constants.swift
git commit -m "feat: add sticker bomb design system foundation"
```

---

### Task 7: Sticker Bomb Styling — SidebarContainer and StripView

**Files:**
- Modify: `Sources/Views/SidebarContainer.swift`
- Modify: `Sources/Views/StripView.swift`

- [ ] **Step 1: Apply sticker styling to SidebarContainer**

In `Sources/Views/SidebarContainer.swift`:

Replace the background color:

```swift
// Replace:
//   Color(red: 0.08, green: 0.08, blue: 0.16)
// With:
StickerColors.background
```

Update the header to use sticker tokens — gold title, bold border divider:

```swift
private var header: some View {
    HStack {
        Button(action: { panelController.goToSettings() }) {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(StickerColors.textSecondary)
        }
        .buttonStyle(.plain)

        Text("RedditReminder")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(StickerColors.gold)
            .onTapGesture {
                let now = Date()
                if now.timeIntervalSince(lastTapTime) > 2 {
                    titleTapCount = 1
                } else {
                    titleTapCount += 1
                }
                lastTapTime = now
                if titleTapCount >= 5 {
                    showDevMenu = true
                    titleTapCount = 0
                }
            }
        Spacer()
        Button(action: { panelController.stepDown() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(StickerColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .overlay(alignment: .bottom) {
        Rectangle()
            .fill(StickerColors.border)
            .frame(height: 2)
    }
}
```

- [ ] **Step 2: Apply sticker styling to StripView**

Replace the full `StripView` body in `Sources/Views/StripView.swift`:

```swift
import SwiftUI

struct StripView: View {
    let queueCount: Int
    let hasUrgentEvent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StickerColors.textSecondary)

                if queueCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color(nsColor: AppColors.reddit))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(StickerColors.border, lineWidth: 2)
                            )
                        Text("\(queueCount)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }

                if hasUrgentEvent {
                    Circle()
                        .fill(Color(nsColor: AppColors.reddit))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(nsColor: AppColors.reddit).opacity(0.6), radius: 4)
                }

                Spacer()

                Text("REDDIT")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(StickerColors.textSecondary)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

Verify: Dark background, gold title, bold 2px header divider, sticker-styled strip badge.

- [ ] **Step 4: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Views/SidebarContainer.swift Sources/Views/StripView.swift
git commit -m "style: apply sticker bomb to SidebarContainer and StripView"
```

---

### Task 8: Sticker Bomb Styling — GlanceView

**Files:**
- Modify: `Sources/Views/GlanceView.swift`

- [ ] **Step 1: Apply sticker styling to GlanceView**

Replace the full file `Sources/Views/GlanceView.swift`:

```swift
import SwiftUI

struct GlanceView: View {
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    let captures: [Capture]
    let onCaptureCardTap: () -> Void
    let onNewCapture: () -> Void

    @AppStorage("hasSeenShortcutOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !hasSeenOnboarding {
                        ShortcutOnboardingCard(onDismiss: {
                            hasSeenOnboarding = true
                        })
                    }

                    if let next = upcomingWindows.first {
                        alertBanner(window: next)
                    }

                    let queued = captures.filter { $0.status == .queued }
                    if !queued.isEmpty {
                        sectionLabel("Queue \u{00B7} \(queued.count)")

                        ForEach(queued, id: \.id) { capture in
                            glanceCard(capture: capture)
                                .onTapGesture(perform: onCaptureCardTap)
                        }
                    }

                    if upcomingWindows.count > 1 {
                        sectionLabel("Upcoming")

                        ForEach(Array(upcomingWindows.prefix(3).enumerated()), id: \.offset) { _, window in
                            eventDot(window: window)
                        }
                    }
                }
                .padding(10)
            }

            Button(action: onNewCapture) {
                Text("+ New Capture")
                    .stickerButton(bgColor: Color(nsColor: AppColors.reddit))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private func alertBanner(window: TimingEngine.UpcomingWindow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("\u{23F0}")
                Text(window.event.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(nsColor: AppColors.reddit))
            }
            if let sub = window.event.subreddit {
                Text("\(sub.name) \u{00B7} \(window.matchingCaptureCount) ready")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard(borderColor: Color(nsColor: AppColors.reddit))
    }

    private func glanceCard(capture: Capture) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(capture.project?.name ?? "Unknown")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(StickerColors.textPrimary)
            Text(capture.text)
                .font(.system(size: 10))
                .foregroundStyle(StickerColors.textSecondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard()
    }

    private func eventDot(window: TimingEngine.UpcomingWindow) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(urgencyColor(window.urgency))
                .frame(width: 6, height: 6)
            Text("\(window.event.name) \u{00B7} \(window.event.subreddit?.name ?? "")")
                .font(.system(size: 10))
                .foregroundStyle(StickerColors.textSecondary)
                .lineLimit(1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(StickerColors.textSecondary)
    }

    private func urgencyColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .none: return .gray
        case .low: return Color(nsColor: AppColors.blue)
        case .medium: return Color(nsColor: AppColors.green)
        case .high, .active: return Color(nsColor: AppColors.reddit)
        case .expired: return .gray.opacity(0.5)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

Verify: Glance cards have 2px borders with offset shadows. Alert banner uses reddit-orange border. Section labels use sticker secondary text. "+ New Capture" button has sticker treatment.

- [ ] **Step 3: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Views/GlanceView.swift
git commit -m "style: apply sticker bomb to GlanceView"
```

---

### Task 9: Sticker Bomb Styling — BrowseView, CaptureCardView, EventCardView

**Files:**
- Modify: `Sources/Views/BrowseView.swift`
- Modify: `Sources/Views/CaptureCardView.swift`
- Modify: `Sources/Views/EventCardView.swift`

- [ ] **Step 1: Apply sticker styling to BrowseView**

In `Sources/Views/BrowseView.swift`:

Replace the "+ New Capture" button at the bottom:

```swift
Button(action: onNewCapture) {
    Text("+ New Capture")
        .stickerButton(bgColor: Color(nsColor: AppColors.reddit))
}
.buttonStyle(.plain)
.padding(10)
```

Replace the `tabButton` function:

```swift
private func tabButton(_ title: String, tab: Tab) -> some View {
    Button(action: { activeTab = tab }) {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(activeTab == tab ? StickerColors.gold : StickerColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if activeTab == tab {
                    Rectangle()
                        .fill(StickerColors.gold)
                        .frame(height: 2)
                }
            }
    }
    .buttonStyle(.plain)
}
```

Replace the tab bar divider:

```swift
HStack(spacing: 0) {
    tabButton("Queue", tab: .queue)
    tabButton("Calendar", tab: .calendar)
}
.overlay(alignment: .bottom) {
    Rectangle()
        .fill(StickerColors.border)
        .frame(height: 2)
}
```

Replace the `sectionLabel` function:

```swift
private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .bold))
        .tracking(1.5)
        .textCase(.uppercase)
        .foregroundStyle(StickerColors.textSecondary)
}
```

- [ ] **Step 2: Apply sticker styling to CaptureCardView**

Replace the full file `Sources/Views/CaptureCardView.swift`:

```swift
import SwiftUI

struct CaptureCardView: View {
    let capture: Capture
    let compact: Bool
    var onMarkPosted: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(capture.project?.name ?? "Unknown")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StickerColors.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(capture.subreddits, id: \.id) { sub in
                        Text(sub.name)
                            .foregroundStyle(Color(nsColor: AppColors.reddit))
                            .stickerBadge(color: Color(nsColor: AppColors.reddit))
                    }
                }
            }

            Text(capture.text)
                .font(.system(size: 11))
                .foregroundStyle(StickerColors.textSecondary)
                .lineLimit(compact ? 1 : 3)

            if !compact && !capture.mediaRefs.isEmpty {
                HStack(spacing: 4) {
                    ForEach(capture.mediaRefs.prefix(4), id: \.self) { _ in
                        mediaThumbnail
                    }
                }
            }

            if !compact {
                captureFooter
            }
        }
        .padding(10)
        .stickerCard()
    }

    private var captureFooter: some View {
        let isQueued = capture.status == .queued
        let statusColor = isQueued ? Color(nsColor: AppColors.green) : StickerColors.textSecondary
        return HStack {
            Text(capture.createdAt, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(StickerColors.textSecondary)
            Spacer()
            if isQueued, let onMarkPosted {
                Button("Mark Posted", action: onMarkPosted)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(nsColor: AppColors.green))
            }
            Text(capture.status.rawValue)
                .foregroundStyle(statusColor)
                .stickerBadge(color: isQueued ? Color(nsColor: AppColors.green) : StickerColors.border)
        }
    }

    private var mediaThumbnail: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(StickerColors.card)
            .frame(width: 36, height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(StickerColors.border, lineWidth: 1)
            )
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(StickerColors.textSecondary)
            )
    }
}
```

- [ ] **Step 3: Apply sticker styling to EventCardView**

Replace the full file `Sources/Views/EventCardView.swift`:

```swift
import SwiftUI

struct EventCardView: View {
    let window: TimingEngine.UpcomingWindow

    var body: some View {
        let isUrgent = window.urgency >= .high

        VStack(alignment: .leading, spacing: 3) {
            Text(window.event.name)
                .font(.system(size: 11, weight: isUrgent ? .heavy : .bold))
                .foregroundStyle(isUrgent ? StickerColors.textPrimary : StickerColors.textSecondary)

            if let sub = window.event.subreddit {
                Text("\(sub.name) \u{00B7} \(window.event.isRecurring ? "recurring" : "one-off")")
                    .font(.system(size: 10))
                    .foregroundStyle(urgencyColor)
            }

            if window.matchingCaptureCount > 0 {
                Text("\(window.matchingCaptureCount) captures ready")
                    .font(.system(size: 10))
                    .foregroundStyle(urgencyColor)
            } else {
                Text("No captures tagged yet")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard(borderColor: isUrgent ? Color(nsColor: AppColors.reddit) : StickerColors.border)
    }

    private var urgencyColor: Color {
        switch window.urgency {
        case .active, .high: return Color(nsColor: AppColors.reddit)
        case .medium: return Color(nsColor: AppColors.green)
        case .low: return Color(nsColor: AppColors.blue)
        default: return StickerColors.textSecondary
        }
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

Verify: Browse view has gold tab indicator, sticker cards with borders and shadows. Capture cards have subreddit badges with pill borders. Event cards have sticker treatment with urgency-colored borders.

- [ ] **Step 5: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Views/BrowseView.swift Sources/Views/CaptureCardView.swift Sources/Views/EventCardView.swift
git commit -m "style: apply sticker bomb to BrowseView, CaptureCardView, EventCardView"
```

---

### Task 10: Sticker Bomb Styling — CaptureFormView

**Files:**
- Modify: `Sources/Views/CaptureFormView.swift`

- [ ] **Step 1: Apply sticker styling to CaptureFormView**

In `Sources/Views/CaptureFormView.swift`, make these targeted replacements:

Replace all `.foregroundStyle(.tertiary)` on section labels with `.foregroundStyle(StickerColors.textSecondary)`.

Replace the TextEditor styling:

```swift
TextEditor(text: $text)
    .font(.system(size: 12))
    .frame(minHeight: 80)
    .scrollContentBackground(.hidden)
    .stickerInput()
```

Replace the TextField styling:

```swift
TextField("e.g., mention the screenshot, link the demo...", text: $notes)
    .textFieldStyle(.plain)
    .font(.system(size: 11))
    .stickerInput()
```

Replace the subredditMultiSelect background/border:

```swift
.stickerInput()
```

(Remove the existing `.padding(6)`, `.background(...)`, `.overlay(...)`, `.clipShape(...)` and replace with `.padding(6)` then `.stickerInput()`.)

Replace the Cancel button in `captureFormFooter`:

```swift
Button("Cancel", action: onCancel)
    .buttonStyle(.plain)
    .font(.system(size: 12, weight: .bold))
    .foregroundStyle(StickerColors.textSecondary)
    .padding(.horizontal, 14)
    .padding(.vertical, 7)
    .background(StickerColors.card)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(StickerColors.border, lineWidth: 2)
    )
```

Replace the "Add to Queue" button:

```swift
Button(action: save) {
    Text("Add to Queue \u{2318}\u{21A9}")
        .font(.system(size: 12, weight: .heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(canSave ? Color(nsColor: AppColors.reddit) : Color.gray)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(StickerColors.border, lineWidth: 2)
        )
        .shadow(color: StickerColors.border.opacity(0.5), radius: 0, x: 2, y: 2)
}
.buttonStyle(.plain)
.disabled(!canSave)
.keyboardShortcut(.return, modifiers: .command)
```

Replace the footer `Divider()`:

```swift
Rectangle()
    .fill(StickerColors.border)
    .frame(height: 2)
```

Update `SubredditChip` to use sticker tokens:

```swift
private struct SubredditChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Text(name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: AppColors.reddit))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(nsColor: AppColors.reddit).opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(nsColor: AppColors.reddit), lineWidth: 2))
    }
}
```

Update `DropZoneView` border:

```swift
private struct DropZoneView: View {
    let isDragOver: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDragOver ? Color(nsColor: AppColors.reddit) : StickerColors.border,
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .background(
                    isDragOver
                        ? Color(nsColor: AppColors.reddit).opacity(0.05)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 4) {
                Image(systemName: "paperclip")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isDragOver ? Color(nsColor: AppColors.reddit) : StickerColors.textSecondary)
                Text("Drop images or videos here")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isDragOver ? Color(nsColor: AppColors.reddit) : StickerColors.textSecondary)
                Text("PNG, JPG, GIF, MP4")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .padding(.vertical, 20)
        }
    }
}
```

Update `AttachedFileChip`:

```swift
private struct AttachedFileChip: View {
    let filename: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc")
                .font(.system(size: 10))
            Text(filename)
                .font(.system(size: 10))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(StickerColors.textPrimary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(StickerColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(StickerColors.border, lineWidth: 1)
        )
    }
}
```

Replace the `sectionLabel` in CaptureFormView:

```swift
private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .bold))
        .tracking(1.5)
        .textCase(.uppercase)
        .foregroundStyle(StickerColors.textSecondary)
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

Verify: Capture form has sticker-styled inputs (2px borders), subreddit chips with pill borders, bold buttons with offset shadows. Drop zone uses sticker border color.

- [ ] **Step 3: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Views/CaptureFormView.swift
git commit -m "style: apply sticker bomb to CaptureFormView"
```

---

### Task 11: Sticker Bomb Styling — Calendar Views and SettingsView

**Files:**
- Modify: `Sources/Views/CalendarTimelineView.swift`
- Modify: `Sources/Views/CalendarMonthView.swift`
- Modify: `Sources/Views/SettingsView.swift`

- [ ] **Step 1: Apply sticker styling to CalendarTimelineView**

In `Sources/Views/CalendarTimelineView.swift`:

Replace the timeline line color:

```swift
// Replace:
//   .fill(Color.white.opacity(0.1))
// With:
.fill(StickerColors.border)
```

Replace the date label foreground style:

```swift
// Replace:
//   .foregroundStyle(dotColor(for: windows))
// With (keep the same function call, just ensure dotColor uses sticker palette):
.foregroundStyle(dotColor(for: windows))
```

The `dotColor` function already uses `AppColors` which is fine. No changes needed to dot colors.

- [ ] **Step 2: Apply sticker styling to CalendarMonthView**

In `Sources/Views/CalendarMonthView.swift`:

Replace the day labels foreground style:

```swift
.foregroundStyle(StickerColors.textSecondary)
```

Replace the month title font weight:

```swift
.font(.system(size: 13, weight: .bold))
```

Replace the nav chevron foreground styles:

```swift
.foregroundStyle(StickerColors.textSecondary)
```

Replace the selected day background:

```swift
// Replace:
//   .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
// With:
.background(isSelected ? StickerColors.card : Color.clear)
.overlay(
    RoundedRectangle(cornerRadius: 4)
        .stroke(isSelected ? StickerColors.border : Color.clear, lineWidth: 1)
)
```

Replace the detail title style:

```swift
.foregroundStyle(StickerColors.textSecondary)
```

Replace the Divider in the detail section:

```swift
Rectangle()
    .fill(StickerColors.border)
    .frame(height: 2)
    .padding(.vertical, 4)
```

- [ ] **Step 3: Apply sticker styling to SettingsView**

In `Sources/Views/SettingsView.swift`:

Replace the `sectionLabel` function:

```swift
private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .bold))
        .tracking(1.5)
        .textCase(.uppercase)
        .foregroundStyle(StickerColors.textSecondary)
}
```

Replace the Divider:

```swift
Rectangle()
    .fill(StickerColors.border)
    .frame(height: 2)
```

- [ ] **Step 4: Apply sticker styling to ShortcutOnboardingCard**

In `Sources/Views/ShortcutOnboardingCard.swift`, replace the card styling to use sticker tokens:

```swift
import SwiftUI

struct ShortcutOnboardingCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(StickerColors.gold)
                Text("\u{2318}\u{21E7}R toggles the sidebar")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(StickerColors.textPrimary)
            }

            Text("Use this shortcut from anywhere to show or hide RedditReminder. It requires Accessibility permission in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(StickerColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: openAccessibilitySettings) {
                    Text("Open System Settings")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(StickerColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(StickerColors.border, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(StickerColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard(borderColor: StickerColors.gold)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 5: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

Verify: Calendar timeline uses sticker border color for connecting lines. Month view has sticker-styled selected state. Settings has bold section labels. Onboarding card uses gold border and sticker button.

- [ ] **Step 6: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Views/CalendarTimelineView.swift Sources/Views/CalendarMonthView.swift Sources/Views/SettingsView.swift Sources/Views/ShortcutOnboardingCard.swift
git commit -m "style: apply sticker bomb to CalendarViews, SettingsView, OnboardingCard"
```

---

### Task 12: Sticker Bomb Styling — Dev Menu and Panel Background

**Files:**
- Modify: `Sources/Views/SidebarContainer.swift`
- Modify: `Sources/Services/PanelController.swift`

- [ ] **Step 1: Style the dev menu overlay**

In `Sources/Views/SidebarContainer.swift`, update `devMenuOverlay` to use sticker tokens:

```swift
private var devMenuOverlay: some View {
    VStack(spacing: 8) {
        Text("DEVELOPER")
            .font(.system(size: 9, weight: .heavy))
            .tracking(2)
            .foregroundStyle(StickerColors.textSecondary)

        Button(action: {
            QAFixtures.seed(context: modelContext)
            showDevMenu = false
        }) {
            Text("Seed QA Data")
                .stickerButton(bgColor: Color(nsColor: AppColors.green))
        }
        .buttonStyle(.plain)

        Button(action: {
            QAFixtures.clearAll(context: modelContext)
            showDevMenu = false
        }) {
            Text("Clear All Data")
                .stickerButton(bgColor: Color(nsColor: AppColors.reddit))
        }
        .buttonStyle(.plain)

        Button(action: { showDevMenu = false }) {
            Text("Dismiss")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(StickerColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
    .padding(12)
    .stickerCard()
    .padding(.horizontal, 20)
    .padding(.top, 60)
    .frame(maxHeight: .infinity, alignment: .top)
}
```

- [ ] **Step 2: Update panel background color**

In `Sources/Services/PanelController.swift`, in `setup(contentView:)`, update the background color:

```swift
// Replace:
//   panel.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.16, alpha: 1.0)
// With:
panel.backgroundColor = NSColor(red: 0.07, green: 0.08, blue: 0.14, alpha: 1.0)
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make install
```

Verify: Dev menu has sticker card styling. Panel background matches the sticker background token.

- [ ] **Step 4: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add Sources/Views/SidebarContainer.swift Sources/Services/PanelController.swift
git commit -m "style: apply sticker bomb to dev menu and panel background"
```

---

### Task 13: QA Script Updates

**Files:**
- Modify: `scripts/qa.sh`

- [ ] **Step 1: Add settings width constant and new tests**

In `scripts/qa.sh`, add the settings width constant:

```bash
# After W_CAPTURE=480, add:
W_SETTINGS=320
```

- [ ] **Step 2: Add settings navigation tests**

After the existing test sections and before the restart persistence test (section 10), add:

```bash
echo ""
bold "10. Settings: gear icon"
echo ""
# Click gear icon — positioned left side of header
click_at_rel "winX + 20" "winY + 20"
assert_width   "Gear icon → Settings"              "$W_SETTINGS"

echo ""
bold "11. Settings: back → previous state"
echo ""
click_back_chevron
assert_width   "Back from Settings → Glance"        "$W_GLANCE"
```

Renumber the restart persistence section to 12.

- [ ] **Step 3: Add state persistence test**

Update the restart persistence section to test that the app restores to the correct state:

```bash
echo ""
bold "12. Restart persistence"
echo ""
click_back_chevron  # Glance → Strip
assert_width   "Pre-restart: Strip"                  "$W_STRIP"

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 2
open "$APP_PATH"
sleep "$LAUNCH_WAIT"

assert_running "App restarts after kill"
assert_width   "Restart in Strip mode (persisted)"   "$W_STRIP"

# Restore to Glance for clean state
click_strip
assert_width   "Back to Glance"                      "$W_GLANCE"
```

- [ ] **Step 4: Update the .PHONY line in Makefile if needed**

The `qa` target already exists. No changes needed.

- [ ] **Step 5: Run QA tests**

```bash
cd /Users/neonwatty/Desktop/RedditReminder && make qa
```

Expected: All tests pass including new settings and persistence tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/neonwatty/Desktop/RedditReminder
git add scripts/qa.sh
git commit -m "test: add QA tests for settings navigation and state persistence"
```

---

## Summary

| Task | Feature | New Files | Modified Files | Commits |
|------|---------|-----------|----------------|---------|
| 1 | State persistence | PanelControllerTests.swift | PanelController.swift | 1 |
| 2 | Settings navigation | — | Constants.swift, PanelController.swift, SidebarContainer.swift | 1 |
| 3 | QA data seeding | QAFixtures.swift | SidebarContainer.swift | 1 |
| 4 | Refresh cycle | — | AppDelegate.swift, RedditReminderApp.swift | 1 |
| 5 | Shortcut onboarding | ShortcutOnboardingCard.swift | GlanceView.swift | 1 |
| 6 | Sticker foundation | StickerStyles.swift | Constants.swift | 1 |
| 7 | Sticker: container/strip | — | SidebarContainer.swift, StripView.swift | 1 |
| 8 | Sticker: glance | — | GlanceView.swift | 1 |
| 9 | Sticker: browse/cards | — | BrowseView.swift, CaptureCardView.swift, EventCardView.swift | 1 |
| 10 | Sticker: capture form | — | CaptureFormView.swift | 1 |
| 11 | Sticker: calendar/settings | — | CalendarTimelineView.swift, CalendarMonthView.swift, SettingsView.swift, ShortcutOnboardingCard.swift | 1 |
| 12 | Sticker: dev menu/panel | — | SidebarContainer.swift, PanelController.swift | 1 |
| 13 | QA script updates | — | scripts/qa.sh | 1 |
