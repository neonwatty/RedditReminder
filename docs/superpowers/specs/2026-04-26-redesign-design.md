# RedditReminder Redesign — Design Spec

## Overview

Redesign of the RedditReminder macOS menu bar app to add channel management with peak time configuration, adaptive sidebar height, links on captures, and Bullhorn-aligned sticker styling.

The app remains a standalone macOS app (not a Bullhorn companion). Discord and social platform support are placeholders only — no implementation in this iteration.

## Interactive Mockup

A full interactive HTML mockup is available at `.superpowers/brainstorm/28891-1777206259/content/full-mockup-v2.html`. Open it in a browser to click through all 6 sidebar states with the final styling.

---

## 1. New `.channels` Sidebar State

### Data Model

No new models. Uses existing `Subreddit` which already has `peakDaysOverride: [String]?` and `peakHoursUtcOverride: [Int]?` fields. The `HeuristicsStore` already supports per-subreddit overrides via `setOverride(for:peakDays:peakHoursUtc:)` and `clearOverride(for:)`.

### State Machine

Add `case channels` to `SidebarState` enum in `Constants.swift`.

```
SidebarState: strip | glance | browse | capture | settings | channels
```

Width: 320pt (same as browse/settings).

### Navigation

- Accessed via new ☰ icon in the header (left side, next to gear)
- Back chevron from channels returns to previous state (same pattern as settings via `previousState`)
- `PanelController` gets `goToChannels()` mirroring `goToSettings()`
- `restoredState()` maps `.channels` → `.glance` (same as `.settings`)

### UI: ChannelsView.swift (new file)

Top-level layout:
1. **Add row** — text field (`r/NewSubreddit`) + green "+" button
2. **REDDIT section** — list of subreddit rows, each expandable
3. **DISCORD section** — placeholder rows, dimmed, "coming soon" badge
4. **SOCIAL section** — placeholder rows, dimmed, "coming soon" badge

Each subreddit row (collapsed):
- Platform dot (reddit orange) + ▶ chevron + name + peak days summary badge

Each subreddit row (expanded, gold border):
- Platform dot + ▼ chevron + name + 🗑 delete
- **NAME** — editable text field, saves to `Subreddit.name`
- **PEAK DAYS** — 7 toggle chips (Mon–Sun), gold when selected. Maps to `Subreddit.peakDaysOverride`
- **PEAK HOURS (UTC)** — chips for even hours 0–22, green when selected. Maps to `Subreddit.peakHoursUtcOverride`
- **Reset to defaults** — link that clears both override arrays (sets to nil) and calls `HeuristicsStore.clearOverride(for:)`

State management: `@State private var expandedSubredditId: UUID?` — only one expanded at a time. Tapping a collapsed row expands it and collapses the previous one.

### Settings Cleanup

Remove the "Subreddits" section from `SettingsView.swift` (lines 91–109, plus `subredditAddRow`, `validatedSubredditName()`, `canAddSubreddit`, `addSubreddit()`, `deleteSubreddit()`). Settings keeps only: sidebar behavior, notifications, auto-collapse.

---

## 2. Updated Header

In `SidebarContainer.swift`, the `header` computed property changes to:

```
Left:  [gear icon] [channels icon ☰]
Center: "RedditReminder"
Right: [back chevron ‹]
```

- Gear icon: `systemName: "gearshape"` — calls `panelController.goToSettings()`
- Channels icon: `systemName: "list.bullet"` — calls `panelController.goToChannels()`
- Active state highlighting: when `panelController.state == .settings`, gear is gold; when `.channels`, list icon is gold; otherwise both are `textSecondary`
- Header still hidden in `.strip` state (unchanged)

---

## 3. Adaptive Sidebar Height

### Constants

Add `SidebarConstants.height(for:)`:

| State | Height |
|---|---|
| `.strip` | `screenFrame.height` (full, unchanged) |
| `.glance` | 240 |
| `.browse` | `screenFrame.height * 0.85` |
| `.capture` | `screenFrame.height * 0.70` |
| `.settings` | 340 |
| `.channels` | `screenFrame.height * 0.85` |

Heights that reference `screenFrame` are computed at positioning time, not as static constants. Fixed-height states (glance, settings) use static values.

### PanelController Changes

1. Rename `animateWidth()` → `animateFrame()` (or keep `animateWidth` and extend it)
2. In the animation block, compute both `targetWidth` and `targetHeight`
3. Anchor panel to top of `visibleFrame` — `frame.origin.y = screenFrame.maxY - targetHeight`
4. Update `positionPanel()` to use `height(for:)` instead of `screenFrame.height`
5. Panel gets `border-radius: 12` on all corners (currently goes edge-to-edge vertically so rounding was less visible)

### Strip Exception

Strip remains full screen height at 24pt width — it's a sliver along the edge, not a floating panel. When transitioning from strip to any other state, both width and height animate simultaneously.

---

## 4. Links on Captures

### Data Model

Add to `Capture`:

```swift
var links: [String]
```

Default to `[]` in the initializer. No migration needed — SwiftData handles new optional/defaulted properties on existing stores.

### CaptureFormView Changes

Add a **LINKS** section between NOTES and PROJECT:

1. Display existing links as blue link chips (blue tint background, link icon, URL text truncated with ellipsis, ✕ remove button)
2. "Paste a URL..." input field + blue "+" add button
3. Adding: validate non-empty, prepend `https://` if no scheme, append to `links` array
4. Removing: tap ✕ on a chip removes from array

### CaptureCardView Changes

When `capture.links` is non-empty, render link chips below the subreddit badges row. Use the same blue link chip style. Truncate long URLs with ellipsis. In compact mode (glance), hide links to save space.

### QAFixtures Update

Add captures with varying link counts:
- Capture with 0 links (existing behavior)
- Capture with 1 link (`github.com/neonwatty/reddit-reminder`)
- Capture with 2 links (repo + live demo URL)

---

## 5. Bullhorn Styling Alignment

All changes in `StickerStyles.swift`. The color palette (`StickerColors`) is already close — no color changes needed.

### StickerCardModifier

```swift
// Before
.stroke(borderColor, lineWidth: 2)
.shadow(color: borderColor.opacity(0.5), radius: 0, x: 2, y: 2)

// After
.stroke(borderColor, lineWidth: 3)
.shadow(color: borderColor, radius: 0, x: 4, y: 4)
```

### StickerButtonModifier

```swift
// Before
.stroke(StickerColors.border, lineWidth: 2)
.shadow(color: StickerColors.border.opacity(0.5), radius: 0, x: 2, y: 2)

// After
.stroke(StickerColors.border, lineWidth: 3)
.shadow(color: StickerColors.border, radius: 0, x: 3, y: 3)
```

Add hover/press interaction: Since this is a macOS app using SwiftUI, use `.onHover` to track hover state and `.buttonStyle` with a custom `PressableButtonStyle` that provides `isPressed`. On hover: `offset(y: -2)`, shadow grows to 4x4. On press: `offset(y: 1)`, shadow shrinks to 2x2.

### StickerBadgeModifier

```swift
// Before: no background fill

// After: add tinted background
.background(color.opacity(0.1))
```

The `color` parameter already exists on the modifier — use it for both border and background tint.

### StickerInputModifier

```swift
// Before
.stroke(StickerColors.border, lineWidth: 2)
// no shadow

// After
.stroke(StickerColors.border, lineWidth: 3)
.shadow(color: StickerColors.border, radius: 0, x: 3, y: 3)
```

---

## 6. Testing

### QA Fixtures (local testing)

Expand `QAFixtures.seed(context:)` to cover all new functionality:

- **Subreddits with peak overrides**: At least one subreddit with custom `peakDaysOverride` and `peakHoursUtcOverride`, one without (uses defaults)
- **Captures with links**: 0, 1, and 2+ links per capture
- **All states exercisable**: seeded data should allow meaningful content in every sidebar state (queue items for browse, upcoming events for calendar, subreddits for channels)

### New Test Files

#### `ChannelsStateTests.swift`
- `.channels` exists in `SidebarState.allCases`
- `SidebarConstants.width(for: .channels)` returns 320
- `SidebarConstants.height(for: .channels)` returns expected value
- `PanelController.restoredState()` maps `.channels` → `.glance`
- `goToChannels()` sets state to `.channels` and saves `previousState`
- `stepDown()` from `.channels` returns to `previousState`
- `goToChannels()` when already in `.channels` is a no-op

#### `CaptureLinksTests.swift`
- `Capture` created with empty links array by default
- `Capture` created with explicit links array preserves them
- Link array mutation (append, remove) works correctly
- `Capture` with links round-trips through creation

#### `SubredditPeakTimeTests.swift`
- Subreddit with nil overrides returns nil from model
- Setting `peakDaysOverride` persists correctly
- Setting `peakHoursUtcOverride` persists correctly
- Clearing overrides (setting to nil) works
- `HeuristicsStore.setOverride` takes priority over bundled data
- `HeuristicsStore.clearOverride` falls back to bundled data
- `isPeakWindow` respects overrides

#### `SidebarHeightTests.swift`
- `height(for:)` returns correct static values for `.glance` (240) and `.settings` (340)
- `height(for: .strip)` returns a large value (full screen proxy)
- All states have a height > 0
- `isWiderThan` still works correctly with new `.channels` state

### Existing Tests Updated

#### `ModelTests.swift`
- Add tests for `Capture` with `links` parameter
- Add test for `Capture` default (empty) links

#### `PanelControllerTests.swift`
- Add `.channels` to `restoredState` tests (channels → glance)
- Add `goToChannels()` tests mirroring `goToSettings()`
- Add `stepDown` from `.channels` test
- Update `isWiderThan` tests to include `.channels`
- Add `toggleCapture` from `.channels` test

---

## Out of Scope

- Discord / Social platform integration (UI placeholders only)
- Multi-platform content calendar backend
- App rename
- Font change to Nunito
- Gradient bar from Bullhorn
