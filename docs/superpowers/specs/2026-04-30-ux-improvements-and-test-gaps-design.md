# UX Improvements & Test Gaps Design

**Date:** 2026-04-30
**Status:** Approved

## Overview

This spec covers 5 UX improvements and 5 test gap closures for the RedditReminder macOS menu bar app. The UX changes focus on reducing visual clutter, preventing accidental data loss, improving feedback clarity, enabling granular posting workflows, and surfacing more scheduling information. The test changes close integration, round-trip, permission, timezone, and UI automation gaps.

---

## UX Improvements

### 1. Hover-to-Reveal Capture Card Actions

**Problem:** `CaptureCardView` shows 5 tiny icon-only buttons (paperplane, copy, open, checkmark, trash) inline at all times. At 12pt/18px, they're visually dense and require hover tooltips to understand.

**Design:**

- **At rest:** Card shows capture summary (title, body preview, subreddit tags, attachment summary, next window text) and the urgency dot. No action buttons visible.
- **On hover:** A compact action bar fades in with labeled buttons: `Post`, `Copy`, `Done`, and a red trash icon. The urgency dot remains visible.
- **Context menu:** Unchanged — right-click shows Edit, Prepare Post, Copy Post Text, Open Reddit, Mark as Posted, Delete. Serves as accessibility and discoverability fallback.

**Implementation approach:**

- Add `@State private var isHovered: Bool = false` to `CaptureCardView`.
- Wrap the card in `.onHover { isHovered = $0 }`.
- Conditionally render the action bar when `isHovered` is true, with a short `.easeInOut` animation.
- Action buttons in hover state use labeled format: icon + short text label (e.g., "Post", "Copy", "Done").
- Delete button shows only the trash icon in red, separated visually from other actions.

**Files affected:** `Sources/Views/CaptureCardView.swift`

### 2. Native macOS Delete Confirmation

**Problem:** Delete on capture cards is immediate with no confirmation and no undo. Captures may represent hours of draft work.

**Design:**

- When delete is triggered (from hover actions or context menu), present a SwiftUI `.confirmationDialog` with:
  - Title: "Delete this capture?"
  - Message: "This action cannot be undone."
  - Destructive button: "Delete"
  - Cancel button (implicit)
- Only applies to the main queue captures. Posted list delete keeps current behavior (lower-risk data).

**Implementation approach:**

- Add `@State private var showDeleteConfirmation: Bool = false` and `@State private var captureToDelete: Capture?` (or handle at the `PopoverContentView` level if the confirmation dialog needs to attach there).
- The `onDelete` closure sets the flag rather than deleting directly.
- `.confirmationDialog` modifier on the card triggers the actual delete on confirmation.

**Files affected:** `Sources/Views/CaptureCardView.swift`, possibly `Sources/Views/PopoverContentView.swift`

### 3. Color-Coded Toasts

**Problem:** `PopoverToastView` renders all toasts identically — no visual distinction between success and error.

**Design:**

- Introduce a `ToastStyle` enum with cases `.success` and `.error`.
- Replace `toastMessage: String?` with `toast: Toast?` where `Toast` is a struct:
  ```swift
  struct Toast {
      let message: String
      let style: ToastStyle
  }
  ```
- **Success toasts:** Green checkmark icon (`checkmark.circle.fill`), green-tinted background (`rgba(34,197,94,0.12)`), green border.
- **Error toasts:** Red X icon (`xmark.circle.fill`), red-tinted background (`rgba(239,68,68,0.12)`), red border.
- Update `PopoverToastView` to accept `Toast` and render based on style.
- Update all call sites in `PopoverContentActions.swift` to pass the appropriate style.

**Files affected:** `Sources/Views/PopoverChromeViews.swift` (PopoverToastView), `Sources/Views/PopoverContentView.swift` (state), `Sources/Utilities/PopoverContentActions.swift` (call sites)

### 4. Per-Subreddit Posting Status

**Problem:** "Mark as Posted" marks a capture as done for all targeted subreddits at once. For multi-subreddit captures, users can't post to r/webdev now and come back for r/SideProject later.

**Design:**

- Add `postedSubredditIDs: [UUID]` to the `Capture` model (default: `[]`).
- Existing `Capture.markAsPosted()` continues to set `status = .posted`, `postedAt = Date()`, and now also fills `postedSubredditIDs` with all subreddit IDs.
- New method `Capture.markSubredditAsPosted(_ id: UUID)`:
  - Appends the ID to `postedSubredditIDs` (if not already present).
  - If all targeted subreddit IDs are now in `postedSubredditIDs`, auto-sets `status = .posted` and `postedAt = Date()`.
- New method `Capture.markSubredditAsUnposted(_ id: UUID)`:
  - Removes the ID from `postedSubredditIDs`.
  - If status was `.posted`, reverts to `.queued` and clears `postedAt`.
- `PostHandoffView` shows a checklist of target subreddits with individual toggle buttons per subreddit, reflecting `postedSubredditIDs`.
- `CaptureCardView` "Done" action keeps the current all-at-once behavior for quick marking from the queue.
- `TimingEngine` counts a capture as "ready" for a subreddit only if that subreddit ID is NOT in `postedSubredditIDs`.
- Backup export/import includes `postedSubredditIDs`.

**Files affected:** `Sources/Models/Capture.swift`, `Sources/Views/PostHandoffView.swift`, `Sources/Services/TimingEngine.swift`, `Sources/Services/BackupService.swift`, `Sources/Services/BackupMappers.swift`, `Sources/Services/BackupTypes.swift`

### 5. Expandable Event Banner

**Problem:** `EventBannerView` shows only the nearest upcoming window and an "and N more" count. Users can't see the full schedule without opening Preferences > Planner.

**Design:**

- Default state unchanged: shows nearest window with subreddit name, relative time, capture count, and "and N more" text.
- Add a disclosure chevron (SF Symbol `chevron.down` / `chevron.up`) to the right side of the banner.
- Tapping the banner toggles `@State var isBannerExpanded: Bool`.
- When expanded, render all remaining `upcomingWindows` as compact rows below the primary banner:
  - Each row: subreddit name, event name, relative time, capture count.
  - Each row is tappable — triggers the same `onTap` filter behavior as the primary banner.
  - Styled consistently with the primary banner but slightly indented and without the orange accent bar.
- Collapsing hides the additional rows with animation.

**Files affected:** `Sources/Views/EventBannerView.swift`, `Sources/Views/PopoverContentView.swift` (state for `isBannerExpanded`)

---

## Test Gaps

### 6. Integration Test — Full Capture Lifecycle

**Purpose:** Verify the happy path end-to-end: capture creation through posting, with timing engine and notification scheduling in the loop.

**Test file:** `Tests/RedditReminderTests/CaptureLifecycleIntegrationTests.swift`

**Tests:**

1. **Full lifecycle happy path:**
   - Create a Subreddit and SubredditEvent with a known RRULE.
   - Create a Capture targeting that subreddit.
   - Run `TimingEngine.refresh()` with a `now` before the event window.
   - Assert `upcomingWindows` contains the event with `matchingCaptureCount == 1`.
   - Run `NotificationScheduler.schedule()` with a mock `NotificationService`.
   - Assert a window notification was scheduled.
   - Call `capture.markAsPosted()`.
   - Refresh the timing engine.
   - Assert `matchingCaptureCount == 0`.

2. **Per-subreddit posting lifecycle:**
   - Create a Capture targeting 3 subreddits, each with events.
   - Verify timing engine shows `matchingCaptureCount == 1` for all 3.
   - Call `capture.markSubredditAsPosted(sub1.id)`.
   - Refresh timing engine.
   - Assert count drops to 0 for sub1 but remains 1 for sub2 and sub3.
   - Assert `capture.status == .queued`.
   - Mark remaining two subreddits as posted.
   - Assert `capture.status == .posted`.

**Infrastructure:** Uses `CRUDTestSupport.makeContainer()` for in-memory SwiftData and existing mock patterns for `NotificationService`.

### 7. BackupService Round-Trip Fidelity Test

**Purpose:** Verify that export followed by import produces identical model state.

**Test file:** `Tests/RedditReminderTests/BackupRoundTripTests.swift`

**Tests:**

1. **Full round-trip fidelity:**
   - Seed: 2 projects, 3 subreddits (each with 1-2 events), 4 captures (mix of queued/posted, with links, media refs, notes, various `postedSubredditIDs` states).
   - Export via `BackupService.export()`.
   - Delete all entities from context.
   - Import the exported data via `BackupService.importBackup()`.
   - Assert field-by-field equality for every entity: projects (name, color, archived, description), subreddits (name, sortOrder, checklist), events (name, rrule, oneOffDate, recurrence fields, isActive, isGeneratedFromHeuristics), captures (title, text, notes, links, mediaRefs, status, postedSubredditIDs, relationship IDs).

2. **Round-trip with empty data:**
   - Export with no entities.
   - Import.
   - Assert zero entities, no errors.

### 8. Notification Permission Denial Tests

**Purpose:** Verify scheduling behavior when permissions are denied or notifications are disabled.

**Test file:** `Tests/RedditReminderTests/NotificationSchedulerPermissionTests.swift`

**Tests:**

1. **Permission denied:** Mock returns `.denied` from `checkPermissionStatus()`. Call `schedule()` with valid events/windows. Assert `cancelAll()` was called, no notifications scheduled, returns `nil`.

2. **Permission not determined:** Mock returns `.notDetermined`. Same assertions.

3. **Notifications disabled in settings:** Mock returns `.authorized`, but `UserDefaults` has `notificationsEnabled = false`. Assert `cancelAll()` was called, returns `nil`.

4. **Permission authorized, notifications enabled:** Mock returns `.authorized`, setting is `true`. Assert notifications ARE scheduled, returns stale count.

### 9. Timezone Edge Case Tests

**Purpose:** Verify `TimingEngine.nextWindow()` and `RRuleHelper.nextOccurrence()` handle cross-timezone and DST scenarios.

**Test file:** `Tests/RedditReminderTests/TimingEngineTimezoneTests.swift`

**Tests:**

1. **Cross-timezone resolution:** Event in `America/New_York` with weekly recurrence at 10:00 AM ET. Compute `nextWindow` with `now` in UTC. Assert the window date is correct in ET.

2. **Day-boundary timezone:** Event in `Asia/Tokyo` with daily recurrence at 1:00 AM JST. Provide `now` as 11:00 PM UTC (which is 8:00 AM JST next day). Verify the engine picks the correct next occurrence, not the one that's already past in JST.

3. **DST spring-forward:** Event in `America/New_York` with daily recurrence at 2:30 AM ET. Provide `now` just before the spring-forward transition. Verify the window doesn't produce an invalid 2:30 AM time (which doesn't exist during spring-forward).

4. **DST fall-back:** Same event, `now` during fall-back. Verify the window doesn't double-fire for the ambiguous 1:00-2:00 AM hour.

### 10. UI Test Expansion

**Purpose:** Cover core user workflows beyond the current smoke-level keyboard shortcut test.

**Test file:** `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift`

**Tests:**

1. **Create capture flow:** Trigger Cmd+N, verify capture window appears. Type a title, verify save button exists. (Full save test depends on subreddit selection which requires QA fixture seeding.)

2. **Preferences tab navigation:** Trigger Cmd+, (or open preferences via menu). Click through all 6 tabs (Channels, Planner, Projects, General, Backup, Notifications) using accessibility identifiers. Verify each tab loads by checking for a known element in each.

3. **Delete confirmation appearance:** With QA fixtures seeded, trigger delete on a capture card. Verify the confirmation dialog appears with "Delete this capture?" text. Tap Cancel. Verify the capture still exists.

**Note:** UI tests depend on `accessibilityIdentifier` values already present in the views. The QA fixture seeding via `AppDelegateQA` provides test data.

---

## Out of Scope

- Reddit API integration (by design — app prepares data, user posts manually)
- Capture templates / cloning
- Keyboard shortcuts within capture editor (Cmd+Enter to save, etc.)
- Analytics / engagement tracking fields
- Menu action registration fix (item 17 from critique — real bug but architectural, separate PR)
