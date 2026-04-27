# UX Redesign: Menu Bar Popover with Apple-Native Styling

**Issue:** #12 — UX redesign: modernize look and reduce clunkiness
**Date:** 2026-04-27
**Status:** Approved

## Summary

Replace the floating NSPanel sidebar with a native macOS menu bar app pattern:
- **NSStatusItem** in the menu bar (replaces strip state)
- **NSPopover** (~350pt wide) for quick queue triage (replaces glance/browse)
- **Capture NSWindow** (~420pt wide) for creating captures (replaces inline capture form)
- **Preferences NSWindow** (~500pt wide) for channels and settings management

Strip all custom "sticker" styling. Use system colors, system fonts, hairline separators, and Reddit orange (#FF4500) as the sole accent color. Automatically supports light and dark mode.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Visual direction | Apple-native (full reset) | Blend into macOS rather than standing out |
| Width model | Single fixed width per surface | Eliminates visual jumping from 6 width states |
| Form factor | Menu bar popover | Standard macOS utility pattern |
| Capture form | Separate window | Keeps popover light; capture window stays open alongside Safari |
| Popover layout | Flat feed | Simplest mental model — open, scan, done |
| Color system | System adaptive | NSColor system colors + Reddit orange accent |
| Settings location | Preferences window | macOS convention; frees popover from management views |

## Surface 1: Menu Bar Icon (NSStatusItem)

Replaces the current strip state. Three visual states:

- **Idle** — Monochrome "R" in a circle. Uses NSImage template rendering so it adapts to the menu bar's light/dark appearance automatically.
- **Badge** — Same icon with an orange (#FF4500) count badge overlay. Appears when one or more captures are queued.
- **Urgent** — Icon itself renders in orange when an event is within the user's configured notification lead time.

**Behavior:**
- Left-click toggles the popover
- No right-click context menu (keep it simple)
- Keyboard shortcut ⌘⇧R toggles popover (preserves existing shortcut)

## Surface 2: Popover (NSPopover, ~350pt)

The primary interaction surface. A flat, scrollable feed for quick triage.

### Layout (top to bottom)

**Header bar:**
- Left: "RedditReminder" label (13pt, semibold)
- Right: Gear icon (opens Preferences window) and "+" button in orange (opens Capture window)

**Event banner (conditional):**
- Only appears when an event is within 24 hours
- Reddit orange left border (3pt) with tinted background (8% opacity orange)
- Shows: subreddit name, event name, time, capture count
- Tapping navigates to that event's captures (filters the feed below)
- When multiple events are within 24h, show the most urgent (soonest) one. Add a small "and 2 more" suffix linking to a stacked view.
- Disappears when no events are imminent

**Capture card feed:**
- Flat scrollable list, no sections or tabs
- Each card shows:
  - Capture text (2-line clamp, 12pt system font)
  - Subreddit name in orange (10pt, medium weight)
  - Attachment indicators: link count, image count, "notes" label (10pt, secondary color)
  - Urgency dot on right edge: orange = high/active, green = medium, none = low/none
- Cards separated by 0.5pt hairline dividers
- Tapping a card opens it in the Capture window for editing

**Footer:**
- Summary line: "5 captures · 1 event upcoming" (10pt, secondary color)
- Centered, purely informational

### Styling

- Background: system window background color (adapts to light/dark)
- Separators: 0.5pt hairline, `separatorColor`
- Typography: SF Pro (system font) throughout
- Corner radius: 10pt (standard NSPopover)
- No custom shadows, no offset effects, no bold borders
- Reddit orange (#FF4500) as sole accent color

### Behavior

- Popover dismisses when clicking outside (standard NSPopover behavior)
- Popover dismisses when opening Capture or Preferences windows
- Popover height is dynamic based on content, with a max height of 85% screen height
- Empty state: centered message "No captures yet" with a "+ New Capture" button

## Surface 3: Capture Window (NSWindow, ~420×480pt)

Standalone window for creating and editing captures. Opens from the popover's "+" button or by tapping a card in the feed.

### Layout (top to bottom)

**Title bar:**
- Title: "New Capture" (or "Edit Capture" when editing)
- Right side: "Cancel" (plain text, secondary color) and "Save" (orange, semibold)

**Fields:**
1. **Capture Text** (required) — Multi-line text area. Primary field, always visible. Minimum height ~72pt.
2. **Subreddit** (required) — Dropdown picker populated from configured channels.
3. **Project** (optional) — Dropdown picker. Defaults to "None".
4. **Notes** (optional) — Multi-line text area. Placeholder: "Add context or reminders..."
5. **Links** — Chip display with domain names. Each chip has an "✕" remove button. "+ Add link" button with dashed border.
6. **Media** — Drop zone at the bottom. "Drop images here or browse" placeholder. Shows thumbnails when populated.

### Styling

- Same system styling as popover: system background, 0.5pt borders on inputs, 8pt corner radius on fields
- Input fields: subtle fill background (system quaternary label at ~6% opacity) with 0.5pt border
- Link chips: blue tint (system blue at 10% opacity) with blue text
- Labels: 10pt, uppercase, medium weight, secondary color, 0.3pt letter spacing

### Behavior

- Opens centered on screen
- ⌘S saves, ⎋ (Escape) cancels
- ⌘N opens a new capture from anywhere in the app
- Window closes on save or cancel
- Standard NSWindow — movable, but not resizable
- When opened from a card tap: pre-populated with that capture's data, title shows "Edit Capture"

## Surface 4: Preferences Window (NSWindow, ~500×440pt)

Standard macOS Preferences window with toolbar-style tab switching.

### Tabs

**Channels tab:**
- Add subreddit row at top: text field + orange "+" button
- Subreddit list below with expandable rows (disclosure triangles)
- Collapsed row: subreddit name (left), schedule summary (right, e.g. "Mon, Thu · 10 AM, 3 PM")
- Expanded row: peak days as toggle chips (7 days, orange when active), peak hours as toggle chips (green when active)
- "Remove" button visible on expanded rows
- Drag-to-reorder preserved from current implementation

**General tab:**
- Keyboard shortcut configuration (⌘⇧R default)
- Default project selection
- Menu bar icon style (monochrome "R" circle — single option for now)

**Notifications tab:**
- Enable/disable notifications toggle
- Lead time picker: 15 min, 30 min, 1 hour before event
- Notification sound picker

### Styling

- Toolbar tabs: standard macOS segmented appearance. Active tab uses orange tint background with orange text.
- Same input and chip styling as Capture window
- Auto-save on all changes (no explicit Save button)

### Behavior

- Opens from gear icon in popover header
- ⌘, shortcut opens Preferences (macOS convention)
- Standard NSWindow — movable, resizable within limits
- Popover dismisses when Preferences opens
- Can stay open independently

## Files Removed

These files are deleted entirely — their functionality is either removed or absorbed into new files:

| File | Reason |
|------|--------|
| `Sources/Views/SidebarContainer.swift` | Replaced by popover content view |
| `Sources/Views/StripView.swift` | Replaced by NSStatusItem menu bar icon |
| `Sources/Views/GlanceView.swift` | Event banner + feed in popover replaces this |
| `Sources/Views/CalendarMonthView.swift` | Calendar removed from scope |
| `Sources/Views/CalendarTimelineView.swift` | Calendar removed from scope |
| `Sources/Views/ShortcutOnboardingCard.swift` | Cut — keyboard shortcut is discoverable in Preferences General tab |
| `Sources/Utilities/StickerStyles.swift` | All custom sticker modifiers replaced by system styling |
| `Sources/Utilities/Constants.swift` | SidebarState enum and width/height constants no longer needed |

## Files Evolved

These files are substantially rewritten but serve the same purpose:

| Current File | Becomes | Changes |
|-------------|---------|---------|
| `Sources/Services/PanelController.swift` | `MenuBarController.swift` | NSPanel → NSStatusItem + NSPopover + window management |
| `Sources/Views/BrowseView.swift` | `PopoverContentView.swift` | Tab-based browse → flat feed |
| `Sources/Views/CaptureFormView.swift` | `CaptureWindowView.swift` | Inline sidebar form → standalone window content |
| `Sources/Views/CaptureCardView.swift` | `CaptureCardView.swift` | Restyled: remove sticker modifiers, use system styling |
| `Sources/Views/EventCardView.swift` | `EventBannerView.swift` | Card with border → inline banner with left accent |
| `Sources/Views/ChannelsView.swift` | `ChannelsTabView.swift` | Restyled for Preferences window context |
| `Sources/Views/SettingsView.swift` | `GeneralTabView.swift` + `NotificationsTabView.swift` | Split into two Preferences tabs |
| `Sources/Views/SubredditRow.swift` | `SubredditRow.swift` | Restyled: system colors, remove sticker chips |
| `Sources/Views/LinkChipView.swift` | `LinkChipView.swift` | Restyled: system blue tint, remove bold borders |
| `Sources/App/AppDelegate.swift` | `AppDelegate.swift` | Wire up NSStatusItem instead of PanelController |
| `Sources/App/RedditReminderApp.swift` | `RedditReminderApp.swift` | Remove hidden keepalive window, use App protocol with MenuBarExtra or manual NSStatusItem |

## Files Unchanged

All models and services remain untouched:

- `Sources/Models/` — Project, Capture, CaptureFormResult, Subreddit, SubredditEvent
- `Sources/Services/NotificationService.swift`
- `Sources/Services/TimingEngine.swift`
- `Sources/Services/HeuristicsStore.swift`
- `Sources/Services/MediaStore.swift`
- `Sources/Utilities/DefaultSubreddits.swift`
- `Sources/Utilities/KeyboardShortcuts.swift`
- `Sources/Utilities/QAFixtures.swift`
- `Sources/Utilities/RRuleHelper.swift`

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧R | Toggle popover (preserved from current) |
| ⌘N | New capture (opens Capture window) |
| ⌘, | Open Preferences |
| ⌘S | Save capture (in Capture window) |
| ⎋ | Cancel/close capture (in Capture window) |

## Animation

- Popover appearance: standard NSPopover animation (system-provided)
- Capture/Preferences window: standard NSWindow `makeKeyAndOrderFront` (no custom animation)
- Feed content: default SwiftUI list animations for insert/remove
- Subreddit row expansion in Preferences: `.easeInOut(duration: 0.2)` (preserved from current)
- No custom frame animations (the 350ms width transitions are eliminated)
