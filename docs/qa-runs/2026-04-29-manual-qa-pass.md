# Manual QA Pass - 2026-04-29

Build: Debug build installed with `make install-debug`

## Workflow 1 - First-Run Setup

Status: Partial pass with automation blockers.

### Steps Exercised

- [x] Installed debug build.
- [x] Launched `~/Applications/RedditReminder.app`.
- [x] Opened Preferences initially.
- [x] Confirmed Channels tab renders with subreddit input and existing subreddit rows.
- [x] Added `r/ManualQAAct` through the Channels UI using real keystrokes.
- [x] Confirmed `r/ManualQAAct` persisted in `~/Library/Application Support/default.store`.
- [ ] Add or edit posting checklist through UI.
- [ ] Collapse and expand the target row.
- [ ] Confirm checklist indicator appears when collapsed.
- [ ] Quit and relaunch, then confirm checklist persists.

### Evidence

Database verification:

```sql
select Z_PK, ZNAME, ZSORTORDER, coalesce(ZPOSTINGCHECKLIST, '')
from ZSUBREDDIT
order by ZSORTORDER, Z_PK;
```

Observed row:

```text
13|r/ManualQAAct|12|
```

### Findings

1. Preferences/menu access is lifecycle-sensitive.

   After a fresh relaunch, the standard app menu exposed only the default macOS app items and did not expose Settings. `Cmd+,` also did not open Preferences in that state. This matches the existing `scripts/qa.sh` workaround that first opens the menu bar popover to wire callbacks.

   Adjustment: register Settings/New Capture handlers independently of `PopoverContentView.onAppear`, or expose stable app-level menu actions at launch.

2. Channels rows and controls need stable accessibility metadata.

   The Channels tab exposes generic `AXButton`, `AXTextField`, and `AXScrollArea` elements with missing names. The subreddit rows, add button, row expand controls, checklist editor, and tab buttons are difficult to target reliably from automation.

   Adjustment: add `accessibilityLabel` / `accessibilityIdentifier` values for Channels tab controls, subreddit rows, expand buttons, remove buttons, and posting checklist editors.

3. Programmatic text-field value assignment is not enough for SwiftUI state updates.

   Setting the subreddit input value directly through Accessibility made text appear visually but did not update SwiftUI state enough for Add to work. Real keystrokes after `tell application "RedditReminder" to activate` did work.

   Adjustment: either rely on keystroke-based QA for this path or add debug QA menu commands for deterministic data setup.

4. Scrolling/targeting lower subreddit rows is fragile.

   The newly added subreddit was appended below the visible rows. Generic scroll-area traversal hung, and keyboard scrolling did not reliably move the list.

   Adjustment: improve accessibility for row lookup and consider making newly added subreddits auto-expand or scroll into view.

### Next Workflow

Continue with Workflow 2 - Create Capture after addressing or accepting the Workflow 1 automation blockers.

## Follow-Up Fix Verification

Status: Fixed the launch/menu and QA automation blockers found during Workflow 1.

### Changes Verified

- [x] `Cmd+,` opens Preferences after a fresh launch.
- [x] The app menu exposes Settings after a fresh launch.
- [x] `scripts/qa.sh` passes end to end.
- [x] Channels controls now include accessibility labels and identifiers for follow-up automation.
- [x] Newly added subreddits now auto-expand in code so the checklist editor is reachable without manual row hunting.

### Automated Evidence

```text
ALL 23 TESTS PASSED
```

## Workflow 2 - Create Capture

Status: Partial pass with an automation blocker.

### Steps Exercised

- [x] Opened New Capture with `Cmd+N`.
- [x] Confirmed the New Capture window appears at the expected 420 px width.
- [x] Confirmed the form visually includes title, capture text, subreddit, project, notes, links, and media fields.
- [x] Confirmed Save is disabled before required content is present.
- [x] Added accessibility labels and identifiers for capture title, body, subreddit picker, project picker, notes, links, Save, and Cancel controls.
- [ ] Enter title/body through automation.
- [ ] Select subreddit through automation.
- [ ] Save through automation.
- [ ] Verify the capture appears in the queue.

### Findings

1. New Capture needs better automation support beyond basic labels.

   The window opens visually and CoreGraphics reports it onscreen, but `System Events` intermittently stops exposing the `New Capture` window after launch/focus changes. This makes text entry and Save automation unreliable even with labels in place.

   Adjustment: add either a small UI-test target that drives the app through XCTest APIs, or debug QA commands that create/edit/delete deterministic captures for smoke coverage. For true end-to-end form input, XCTest is the better fit than AppleScript.

2. The form previously lacked stable accessibility metadata.

   Title, body, subreddit picker, project picker, notes, links, Save, and Cancel did not have explicit labels/identifiers. These are now added in code for follow-up automation and assistive-tech clarity.

### Verification After Adjustments

- `make test` passed: 348 tests.
- `./scripts/format-check.sh` passed.
