# RedditReminder — Design Spec

A native macOS sidebar app for capturing project updates and getting nudged about optimal Reddit posting times.

## Problem

The bottleneck in posting to Reddit isn't the mechanics of submitting — it's remembering to post at the right time. Subreddits have peak hours and recurring community events (Show-off Saturday, What Are You Working On Wednesday). Missing these windows means less traction. The current workflow requires opening a web app, remembering the schedule, and having content ready — too many steps to do consistently.

## Solution

A persistent sidebar anchored to the screen edge, visible on all macOS Spaces. It serves as:

1. **A content reservoir** — capture project updates (text + media) whenever inspiration strikes, tagged with target subreddits
2. **A timing assistant** — knows when subreddit events and peak hours occur, matches queued captures to upcoming windows
3. **A nudge system** — escalating visual and notification cues as posting windows approach

The user handles the actual posting. RedditReminder ensures they don't miss the window and have something ready.

## Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| UI framework | SwiftUI + AppKit hybrid | NSPanel for the sidebar window; SwiftUI views inside via NSHostingController. Matches existing menu bar app patterns (session-search, space-labeler) |
| Persistence | SwiftData (SQLite) | Declarative models with automatic migrations and native SwiftUI bindings. macOS 14+ required |
| Media storage | App sandbox file system | `~/Library/Application Support/RedditReminder/media/` with generated thumbnails (mac-screenshot pattern) |
| Build system | XcodeGen + Makefile | Consistent with session-search, CCSwitcher, space-labeler |
| Min deployment | macOS 14.0+ | Required for SwiftData; CCSwitcher already targets 14+ |
| Language | Swift 6.0 | Strict concurrency (CCSwitcher pattern) |

## Data Model

### Project

A thing you're building — organizes captures.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | String | e.g., "Bullhorn", "SessionSearch" |
| description | String? | Optional |
| color | String? | Hex color for visual distinction |
| archived | Bool | Hidden from pickers when true |
| createdAt | Date | |

### Capture

A post-worthy update waiting in the queue.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| text | String | The update content (rough notes, polished later) |
| notes | String? | Private notes-to-self ("mention the screenshot") |
| mediaRefs | [String] | Filenames in media directory |
| status | CaptureStatus | `.queued` or `.posted` |
| project | Project | Relationship |
| subreddits | [Subreddit] | Many-to-many relationship |
| createdAt | Date | |
| postedAt | Date? | When user marked as posted |

### Subreddit

A target subreddit with optional peak-hours override.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | String | e.g., "r/SideProject" |
| peakDaysOverride | [String]? | User override of heuristic peak days |
| peakHoursUtcOverride | [Int]? | User override of heuristic peak hours |

### SubredditEvent

A recurring or one-off posting window.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | String | e.g., "Show-off Saturday" |
| subreddit | Subreddit | Relationship |
| rrule | String? | RRULE string for recurring events |
| oneOffDate | Date? | For non-recurring events (launch days) |
| reminderLeadMinutes | Int | How far before the event to nudge (default: 60) |
| isActive | Bool | Can be disabled without deleting |

### Relationships

```
Project ──1:many──▶ Capture ──many:many──▶ Subreddit
                                               ▲
                                               │
                              SubredditEvent ──┘
```

When a SubredditEvent is approaching, the TimingEngine checks for queued captures targeting that subreddit. If matches exist → nudge with content. If none exist → optionally nudge to capture something.

## Sidebar Form Factor

### Window Implementation

An `NSPanel` configured for persistent, non-intrusive presence:

```swift
let panel = NSPanel(...)
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.level = .floating
panel.styleMask.insert(.nonactivatingPanel)
panel.isMovableByWindowBackground = false
// Anchor to configured screen edge (left or right)
```

Properties:
- **Visible on all Spaces/desktops** — follows the user everywhere
- **Non-activating** — clicking the sidebar doesn't steal focus from the active app
- **Floating** — stays above normal windows, below system alerts
- **Survives full-screen** — remains accessible via `.fullScreenAuxiliary`

### Four Width States

The sidebar has four distinct widths, transitioned with spring animation (~0.3s via `NSAnimationContext`).

| State | Width | Purpose | Content |
|-------|-------|---------|---------|
| **Strip** | 24px | Minimal footprint | Queue count badge, event urgency dot, vertical "REDDIT" label |
| **Glance** | 200px | Passive awareness | Next posting window countdown, condensed queue list (project + one-liner), upcoming events peek (next 3) |
| **Browse** | 320px | Review and plan | Full capture cards (text preview, media thumbnails, subreddit tags, metadata), calendar with timeline/month toggle, filter by project/subreddit, mark as posted |
| **Capture/Manage** | 480px | Create, edit, configure | New capture form (project picker, subreddit multi-select, text area, notes, media drop zone), edit existing captures, manage projects/subreddits/events, settings |

### State Transitions

```
┌───────┐    click      ┌────────┐   click card   ┌────────┐   + Capture   ┌─────────┐
│ Strip │ ──────────────▶ │ Glance │ ──────────────▶ │ Browse │ ───────────▶ │ Capture │
│ 24px  │                 │ 200px  │                 │ 320px  │              │ 480px   │
└───────┘ ◀────────────── └────────┘ ◀────────────── └────────┘ ◀─────────── └─────────┘
              Esc               Esc                      Esc / Cancel

              ◀──────────────────────── ⌘⇧R from any state ────────────────────────▶
```

| Action | Transition |
|--------|------------|
| `⌘⇧R` (global hotkey) | Any state → Capture (480px). If already at 480, focus the text field |
| Click strip | Strip → Glance |
| Click a capture card in Glance | Glance → Browse, scrolled to that card |
| "+ New Capture" button or `⌘⇧N` | Any → Capture (480px) |
| `Esc` | Step down one level (Capture → Browse → Glance → Strip) |
| Idle timeout (configurable) | Auto-collapse to configured resting state |

### PanelController

The core state machine — an `@Observable` class that owns the `NSPanel` and drives the SwiftUI view hierarchy.

Responsibilities:
- Manages `enum SidebarState { case strip, glance, browse, capture }` as published state
- Animates width transitions via `NSAnimationContext` with spring timing
- Anchors panel to screen edge (left or right) and full screen height
- Handles idle timeout logic (resets on any user interaction)
- Exposes `stepDown()`, `setState(_:)`, and `toggleCapture()` methods

## Calendar

Two views under the Calendar tab, toggled with a segmented control:

### Timeline View (action-oriented)

A vertical scrollable list of upcoming events, ordered chronologically. Each item shows:
- Date with urgency-colored dot
- Event name and subreddit
- Recurring badge (weekly/monthly) or one-off indicator
- Count of matching queued captures

Best at **Glance** (condensed) and **Browse** (full detail) widths.

### Month View (planning-oriented)

A traditional month grid calendar. Days with events show colored dots matching the event type:
- Reddit-orange — recurring community events (Show-off Saturday)
- Blue — recurring thread events (WAYW Wednesday)
- Green — peak hours windows
- Purple — custom one-off events

Tapping a day shows that day's events below the grid with full detail. Navigation arrows to move between months.

Best at **Browse** and **Manage** widths.

### How they complement each other

| | Timeline | Month |
|-|----------|-------|
| Question answered | What's my next posting window? | What does my posting rhythm look like? |
| Strength | Event details, matched captures, urgency | Spotting gaps, clusters, planning launches |
| Interaction | Scroll vertically through upcoming | Tap a day to see details |

## Timing Engine

### Two sources of timing data

**1. Subreddit Events (user-configured)**

Named, scheduled posting windows. Created manually by the user:
- "Show-off Saturday" → r/SideProject, RRULE: every Saturday
- "What Are You Working On Wednesday" → r/webdev, RRULE: every Wednesday
- "Launch day" → r/SideProject + r/indiehackers, May 15 one-off

Each event has a configurable reminder lead time (default: 1 hour before).

**2. Peak Hours (heuristic, baked-in)**

General "best time to post" data per subreddit. Ships as a bundled JSON resource:

```json
{
  "r/SideProject": { "peak_days": ["tue", "sat"], "peak_hours_utc": [14, 15, 16] },
  "r/webdev": { "peak_days": ["tue", "thu"], "peak_hours_utc": [14, 15] },
  "r/MacApps": { "peak_days": ["mon", "wed"], "peak_hours_utc": [15, 16] },
  "r/indiehackers": { "peak_days": ["tue", "thu"], "peak_hours_utc": [14, 15, 16] }
}
```

Users can override peak data for any subreddit. Overrides stored in SwiftData; bundled data is the fallback.

### Matching Algorithm

Runs every 5 minutes via a background `Timer`:

```
for each upcoming window (events + peak hours) in the next 24 hours:
    find queued captures targeting that subreddit
    if matches exist:
        compute urgency (hours until window)
        update sidebar ambient state (color, glow, text)
        if urgency crosses notification threshold → fire macOS notification
    if no matches but event is within 12 hours:
        optionally nudge: "Show-off Saturday tomorrow — nothing queued for r/SideProject"
```

### Urgency Levels

Drive the sidebar's ambient visual state and notification behavior.

| Time to Window | Level | Sidebar Visual | Notification |
|---------------|-------|----------------|-------------|
| > 24 hours | None | Gray dot, dim text | — |
| 12–24 hours | Low | Colored dot appears | — |
| 2–12 hours | Medium | Colored border, event highlighted | Optional (if configured) |
| < 2 hours | High | Glowing border, pulsing dot | macOS notification fires |
| Window open now | Active | Full glow, "POST NOW" state | Second notification if not dismissed |
| Window passed | Expired | Strikethrough, faded | — |

### Nudge Layers

Four escalation levels — the first two are ambient (sidebar-only), the last two reach beyond.

| Layer | Mechanism | When |
|-------|-----------|------|
| **1. Ambient** | Sidebar color/glow changes | Always — passive visual state |
| **2. Badge** | Collapsed strip pulses, badge count updates | Event within 2 hours + captures ready |
| **3. macOS notification** | System banner via `UNUserNotificationCenter` | Configurable lead time (default 1 hour) |
| **4. Sound** | Optional subtle chime | Only for high-priority custom events |

### Future: Live Analysis (v2+)

Not in v1. The `HeuristicsStore` is protocol-based so it can swap from static JSON to a service that polls Reddit's API (`/r/{subreddit}/new.json`) and learns optimal windows per subreddit based on post velocity by hour. The `TimingEngine` is agnostic to the data source.

## Capture Flow

### Quick Capture

1. User presses `⌘⇧R` from any app or clicks "+ New Capture"
2. Sidebar widens to 480px, capture form appears, text field focused
3. User selects project from dropdown (remembers last used)
4. User selects target subreddits (multi-select, also remembers last used)
5. User types update text (rough is fine)
6. Optional: drag-and-drop images/videos onto drop zone, or click to browse
7. Optional: add notes-to-self
8. Press `⌘↵` or click "Add to Queue"
9. Capture saved, sidebar returns to previous width state

### Media Handling

- Drag-and-drop onto the drop zone in the capture form
- Supported: PNG, JPG, GIF, MP4, MOV
- Files copied to `~/Library/Application Support/RedditReminder/media/{captureId}/`
- Thumbnails generated on save (max 200px, same approach as mac-screenshot)
- Thumbnails displayed on capture cards in queue view
- Original files available when user clicks to view

### Capture Lifecycle

```
queued → posted (user marks manually after posting to Reddit)
```

Captures are not auto-deleted when marked as posted — they move to a "Recently Posted" section and can be cleared from settings.

## Project Structure

```
RedditReminder/
├── App/
│   ├── RedditReminderApp.swift       # @main entry, AppDelegate setup
│   └── AppDelegate.swift             # NSPanel init, global shortcut, Timer for TimingEngine
├── Models/
│   ├── Project.swift                 # SwiftData @Model
│   ├── Capture.swift                 # SwiftData @Model
│   ├── SubredditEvent.swift          # SwiftData @Model
│   └── Subreddit.swift               # SwiftData @Model
├── Services/
│   ├── PanelController.swift         # NSPanel lifecycle, width state machine, edge anchoring
│   ├── TimingEngine.swift            # Window matching, urgency computation, notification scheduling
│   ├── NotificationService.swift     # UNUserNotificationCenter wrapper
│   ├── MediaStore.swift              # File system storage, thumbnail generation
│   └── HeuristicsStore.swift         # Bundled peak times JSON, user overrides, protocol for future live data
├── Views/
│   ├── SidebarContainer.swift        # Root SwiftUI view — switches content by SidebarState
│   ├── StripView.swift               # 24px badge + dot
│   ├── GlanceView.swift              # 200px ambient status
│   ├── BrowseView.swift              # 320px queue + calendar tabs
│   ├── CaptureFormView.swift         # 480px new/edit form
│   ├── CalendarTimelineView.swift    # Vertical timeline
│   ├── CalendarMonthView.swift       # Month grid + day detail
│   ├── CaptureCardView.swift         # Adaptive card (renders differently per width)
│   ├── EventCardView.swift           # Timeline event card
│   └── SettingsView.swift            # Preferences panel
├── Utilities/
│   ├── KeyboardShortcuts.swift       # Global hotkey registration (CGEvent tap)
│   ├── RRuleHelper.swift             # RRULE parsing and expansion
│   └── Constants.swift               # Widths, durations, colors
├── Resources/
│   └── peak-times.json               # Bundled subreddit heuristics
├── project.yml                        # XcodeGen project definition
└── Makefile                           # build, install, clean, launch-at-login
```

### Architectural Patterns (from existing apps)

| Pattern | Source | Usage |
|---------|--------|-------|
| `NSStatusBar` + `NSPopover` + `NSHostingController` | session-search, space-labeler | Adapted to `NSPanel` + `NSHostingController` for the sidebar |
| `@Observable` / `@Published` state management | All four apps | `PanelController` and `TimingEngine` as `@Observable` classes |
| Dependency injection via init | All four apps | Controllers receive their stores and services |
| `@MainActor` on UI state | session-search, CCSwitcher | All view-facing classes |
| `Task.detached` for heavy work | session-search, CCSwitcher | Media thumbnail generation, timing engine calculations |
| Serial `DispatchQueue` for data access | session-search | SwiftData context access |
| `Timer.scheduledTimer` for polling | session-search, CCSwitcher | TimingEngine 5-minute matching cycle |
| File system + sidecar metadata | mac-screenshot | Media storage with thumbnails |
| XcodeGen + Makefile | session-search, CCSwitcher, space-labeler | Build system |

## Settings

### Sidebar Behavior

| Setting | Options | Default |
|---------|---------|---------|
| Screen edge | Left / Right | Right |
| Resting state | Strip / Glance / Browse | Glance |
| Auto-collapse timeout | 1 / 5 / 15 / 30 min / Never | 5 min |
| Auto-collapse target | Strip / Glance | Resting state |
| Launch at login | On / Off | On |
| Global shortcut | Customizable hotkey | ⌘⇧R |

### Notifications

| Setting | Options | Default |
|---------|---------|---------|
| macOS notifications | On / Off | On |
| Default lead time | 30 min / 1 hr / 2 hr | 1 hour |
| Per-event lead time | Custom override per event | Inherits default |
| Nudge when queue empty | On / Off | On |
| Sound | None / subtle chime / system default | None |

### Data Management

| Setting | Description |
|---------|-------------|
| Manage projects | Add, rename, archive, set color |
| Manage subreddits | Add, remove, edit peak hours override |
| Export data | JSON export of all captures, events, projects |
| Clear posted | Remove all captures marked as "posted" |
| Database location | Shows path to SwiftData store |

## Distribution

- **Format**: standalone `.app` bundle in a DMG
- **Signing**: Developer ID for direct distribution (no App Store required)
- **Updates**: manual download or Sparkle framework for auto-updates (v2)
- **Size target**: < 5 MB binary

## Out of Scope (v1)

- Posting to Reddit (user posts manually)
- GitHub milestone detection (future feature)
- Live subreddit activity analysis (future — static heuristics for v1)
- Cloud sync or multi-device (purely local)
- iOS companion app
- Sparkle auto-updates (manual DMG for v1)
