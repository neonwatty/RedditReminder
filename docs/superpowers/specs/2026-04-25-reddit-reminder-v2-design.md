# RedditReminder v2 — Design Spec

**Date:** 2026-04-25
**Status:** Draft
**Scope:** 6 features in a single branch, built sequentially

## Goal

Ship RedditReminder v2 with functional improvements (state persistence, settings access, data seeding, refresh cycle wiring, shortcut onboarding) and a visual overhaul porting Bullhorn's sticker bomb design system to the native macOS sidebar.

## Architecture

SwiftUI + AppKit hybrid. NSPanel floating sidebar with SwiftData persistence. All 6 features are independent and will be built in dependency order within a single branch. Styling is last so every view gets one clean pass.

## Build Order

1. State persistence
2. Settings navigation
3. Data seeding (hidden dev menu)
4. Refresh cycle wiring
5. Shortcut onboarding
6. Sticker bomb styling

---

## 1. State Persistence

### What

Save the current sidebar state to `@AppStorage("sidebarState")` on every `setState()` call. Restore on launch in `PanelController.setup()`.

### Smart Default

If the persisted state is `.capture`, restore to `.browse` instead. Reopening into an empty capture form with no context is disorienting.

### Files

- **Modify:** `Sources/Services/PanelController.swift` — add `@AppStorage` property, read on setup, write on setState

### Behavior

- State saved as raw string (enum rawValue)
- Read on launch before `positionPanel()`
- `.capture` → `.browse` fallback
- `.settings` → `.glance` fallback (settings is transient)

---

## 2. Settings Navigation

### What

Add a gear icon button to the sidebar header. Tapping it enters a `.settings` sidebar state that displays the existing `SettingsView`.

### New Sidebar State

Add `.settings` to `SidebarState` enum. Width: 320px (same as `.browse`). Settings does **not** participate in the normal strip→glance→browse→capture step-down ladder.

### Back Behavior

Back chevron from `.settings` returns to the state the user came from (stored as `previousState` in PanelController), not a fixed step-down.

### Files

- **Modify:** `Sources/Utilities/Constants.swift` — add `.settings` case to `SidebarState`, add width mapping
- **Modify:** `Sources/Views/SidebarContainer.swift` — add gear icon to header, add `.settings` case to view switch
- **Modify:** `Sources/Services/PanelController.swift` — store `previousState`, handle `.settings` back navigation

### Behavior

- Gear icon visible in all states except `.strip` (no room at 24px width)
- Gear icon position: left side of header, opposite the back chevron
- `stepDown()` from `.settings` returns to `previousState` (defaults to `.glance`)
- Tapping gear while already in `.settings` is a no-op (don't overwrite `previousState`)

---

## 3. Data Seeding (Hidden Dev Menu)

### What

5-tap on the "RedditReminder" header title reveals a developer menu with seed/clear buttons. Predefined fixtures for QA testing.

### Activation

5 taps within 2 seconds on the "RedditReminder" title text in the header.

### Fixture Set

- **3 subreddits:** `r/SideProject`, `r/SwiftUI`, `r/macOS`
- **5 captures:** mix of `.draft` and `.queued` statuses, spread across subreddits
- **2 subreddit events:** one upcoming (7 days from now), one overdue (1 day ago)
- **1 project:** linking `r/SideProject` and `r/SwiftUI`

### Dev Menu Contents

- **"Seed QA Data"** — clears existing data first (idempotent), then inserts fixtures
- **"Clear All Data"** — wipes all SwiftData entities

### Files

- **Modify:** `Sources/Views/SidebarContainer.swift` — tap counter on title, show/hide dev menu overlay
- **Create:** `Sources/Utilities/QAFixtures.swift` — fixture data definitions and insert/clear functions

### Behavior

- Dev menu appears as a small overlay below the header
- Seeding is idempotent (clears first, no duplicates)
- Dev menu stays visible until dismissed or app restarted
- Uses `@Environment(\.modelContext)` already available in SidebarContainer

---

## 4. Refresh Cycle Wiring

### What

Wire `runRefreshCycle()` in AppDelegate to actually compute upcoming windows and schedule/cancel macOS notifications. Currently it just logs.

### Problem

AppDelegate has no access to SwiftData's `ModelContext`. It creates TimingEngine and NotificationService but can't fetch events and captures.

### Solution

Pass the `ModelContainer` from `RedditReminderApp` to AppDelegate. Create a read-only `ModelContext` in `runRefreshCycle()`.

### Refresh Flow (every 5 minutes + on launch)

1. Create `ModelContext` from shared container
2. Fetch active `SubredditEvent`s and queued `Capture`s
3. Call `timingEngine.refresh(events:captures:)` to compute `UpcomingWindow`s
4. For each window: call `notificationService.scheduleWindowNotification()`
5. If window has 0 matching captures and nudge setting enabled: call `scheduleEmptyQueueNudge()`
6. Cancel notifications for events no longer in the active set

### Files

- **Modify:** `Sources/App/AppDelegate.swift` — accept `ModelContainer`, implement full refresh logic
- **Modify:** `Sources/App/RedditReminderApp.swift` — pass container to AppDelegate

### Not in Scope

`HeuristicsStore` peak-time optimization. It exists but isn't critical for v2.

---

## 5. Shortcut Onboarding

### What

On first launch, show a dismissible card in the Glance view explaining ⌘⇧R and guiding the user to grant Accessibility permission.

### Card Content

- Headline: "Use ⌘⇧R to toggle the sidebar from anywhere"
- Body: brief explanation that Accessibility permission is needed
- **"Open System Settings" button** — deep-links to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- **"Dismiss" button** — hides permanently

### Persistence

`@AppStorage("hasSeenShortcutOnboarding")` — defaults to `false`, set to `true` on dismiss.

### Design Decision

The card does **not** check live permission status via `AXIsProcessTrusted()`. That would require polling and adds complexity for little benefit. The user either grants it or doesn't.

### Files

- **Create:** `Sources/Views/ShortcutOnboardingCard.swift` — the card view
- **Modify:** `Sources/Views/GlanceView.swift` — conditionally show card at top

---

## 6. Sticker Bomb Styling

### What

Port Bullhorn's sticker bomb design system to every SwiftUI view. Create shared color palette and reusable ViewModifiers, then apply across all views.

### Design Tokens (adapted for narrow sidebar)

| Token | CSS | Swift Color |
|-------|-----|-------------|
| Background | `hsl(220, 20%, 10%)` | `Color(red: 0.07, green: 0.08, blue: 0.14)` |
| Card | `hsl(220, 18%, 14%)` | `Color(red: 0.10, green: 0.11, blue: 0.19)` |
| Border | `hsl(220, 15%, 35%)` | `Color(red: 0.27, green: 0.29, blue: 0.40)` |
| Primary (gold) | `hsl(43, 96%, 50%)` | `Color(red: 0.81, green: 0.60, blue: 0.03)` |
| Accent (pink) | `hsl(330, 80%, 60%)` | `Color(red: 0.93, green: 0.29, blue: 0.60)` |
| Reddit orange | `#FF4500` | existing `AppColors.reddit` |
| Text primary | `hsl(0, 0%, 95%)` | `Color(red: 0.95, green: 0.95, blue: 0.95)` |
| Text secondary | `hsl(220, 10%, 60%)` | `Color(red: 0.55, green: 0.56, blue: 0.63)` |

### Sticker Treatment (scaled for sidebar)

| Element | Border | Shadow | Radius |
|---------|--------|--------|--------|
| Card | 2px solid border | 2px 2px offset, border color | 10px |
| Button | 2px solid border | 2px 2px offset, border color | 8px |
| Badge | 2px solid border | none | pill |
| Header divider | 2px solid border | — | — |

### Font

System font with `.bold` and `.heavy` weights. Nunito is not available in native macOS — heavy system font weights approximate the sticker bomb feel.

### Shared Styles

Create `StickerStyles.swift` with:
- `StickerColors` enum — all color constants
- `.stickerCard()` ViewModifier — background, border, shadow, radius
- `.stickerButton()` ViewModifier — border, shadow, heavy weight text
- `.stickerBadge()` ViewModifier — pill border

### Files

- **Create:** `Sources/Utilities/StickerStyles.swift` — colors, ViewModifiers
- **Modify:** `Sources/Views/SidebarContainer.swift` — header, background
- **Modify:** `Sources/Views/StripView.swift` — badge, text colors
- **Modify:** `Sources/Views/GlanceView.swift` — cards, section headers
- **Modify:** `Sources/Views/BrowseView.swift` — list items, cards
- **Modify:** `Sources/Views/CaptureFormView.swift` — form inputs, buttons
- **Modify:** `Sources/Views/CaptureCardView.swift` — card styling
- **Modify:** `Sources/Views/EventCardView.swift` — card styling
- **Modify:** `Sources/Views/CalendarMonthView.swift` — calendar styling
- **Modify:** `Sources/Views/CalendarTimelineView.swift` — timeline styling
- **Modify:** `Sources/Views/SettingsView.swift` — form styling
- **Modify:** `Sources/Views/ShortcutOnboardingCard.swift` — card styling
- **Modify:** `Sources/Utilities/Constants.swift` — update `AppColors` to use sticker palette

---

## QA Script Updates

The existing `scripts/qa.sh` will need updates after these changes:

- State persistence test: verify app restores to last state (not always Glance)
- Settings navigation: click gear icon, verify settings width, click back
- Data seeding: activate dev menu via 5-tap, seed data, verify content appears

---

## Out of Scope

- `HeuristicsStore` integration for peak-time posting optimization
- Custom font bundling (Nunito) — system heavy weights are sufficient
- Live Accessibility permission checking for shortcut onboarding
- Reddit API integration (posting, auth)
