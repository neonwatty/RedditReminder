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

## Workflow 2 Follow-Up - Deterministic Posting Handoff

Status: Passed with debug QA coverage.

### Changes Verified

- [x] Debug QA can create a deterministic queued capture titled `QA Workflow Capture`.
- [x] Debug QA can copy the first queued capture title for verification.
- [x] Debug QA can copy the deterministic capture body plus link.
- [x] Debug QA can copy the deterministic Reddit submit URL.
- [x] Seeded posting handoff still copies the original seeded body and submit URL.
- [x] Mark Posted advances the first queued capture.

### Automated Evidence

```text
ALL 26 TESTS PASSED
```

## Workflow 3 - Post Handoff

Status: Passed after accessibility and lifecycle fixes.

### Steps Exercised

- [x] Created a deterministic queued capture through the debug QA menu.
- [x] Opened the post handoff window from the capture card.
- [x] Confirmed title, body, destination subreddit, link, and checklist content render correctly.
- [x] Copied the title and verified clipboard content.
- [x] Copied the body and verified clipboard content.
- [x] Copied links and verified clipboard content.
- [x] Copied all post content and verified formatting.
- [x] Used the Reddit submit/open action.
- [x] Confirmed the body plus link were copied and Reddit opened in the browser.

### Evidence

Deterministic capture:

```text
Title: QA Workflow Capture
Body: Created by RedditReminder automated QA.
Subreddit: r/SideProject
Link: https://example.com/reddit-reminder-qa
```

Copy All clipboard:

```text
QA Workflow Capture

Created by RedditReminder automated QA.

https://example.com/reddit-reminder-qa
```

Open Reddit action:

```text
Clipboard:
Created by RedditReminder automated QA.

https://example.com/reddit-reminder-qa

Frontmost app: Google Chrome
Crash changed: no
```

### Findings

1. Post handoff buttons needed stable accessibility metadata.

   Icon-only copy/open actions were visually clear but exposed weak names and no stable identifiers to automation. The handoff copy buttons now expose identifiers for title, body, links, Copy All, Mark Posted, and Open Reddit.

2. Capture card action buttons needed accessible names.

   The card-level icon actions now use labeled SwiftUI controls with icon-only styling, which keeps the current UI while improving assistive-tech and automation support.

3. Debug deletion could invalidate visible capture models.

   Deleting a visible QA capture while the popover or handoff window still referenced it could leave SwiftData-backed views reading a deleted model. The QA cleanup path now closes handoff UI and dismisses the popover before deleting deterministic captures.

4. Closing the last handoff window could terminate the menu bar app.

   The app now remains resident when the last normal window closes, matching expected menu bar app behavior.

### Verification After Adjustments

- `make test` passed: 353 tests.
- `./scripts/qa.sh` passed: 26 tests.

## Workflow 4 - Mark Posted

Status: In progress, with automation coverage added and passing.

### Steps Exercised

- [x] Marked a deterministic queued capture as posted with a saved Reddit URL through the debug QA menu.
- [x] Confirmed the posted record summary includes title, body, subreddit, and saved URL.
- [x] Copied the saved posted URL for verification.
- [x] Marked another deterministic queued capture as posted with no URL.
- [x] Confirmed posted history records the capture without showing a broken link value.
- [ ] Complete a visual/manual pass through the popover Posted tab.
- [ ] Open the saved Reddit URL from the posted-history UI.

### Evidence

Posted summary with URL:

```text
Title: QA Workflow Capture
Body: Created by RedditReminder automated QA.
Subreddit: r/SideProject
Posted URL: https://www.reddit.com/r/SideProject/comments/qa123/reddit_reminder_qa/
```

Posted summary without URL:

```text
Title: QA Workflow Capture
Body: Created by RedditReminder automated QA.
Subreddit: r/SideProject
Posted URL: <none>
```

### Findings

1. Posted-history workflow needed stable automation hooks.

   Added debug QA menu actions for marking a deterministic capture posted with a URL, copying the newest posted summary, and copying the newest posted URL.

2. Popover posted/queue controls needed stable identifiers.

   Added accessibility identifiers for the Queue and Posted segmented controls so the posted-history view can be targeted in follow-up manual automation.

3. Posted link and capture card actions needed stable labels/identifiers.

   Posted-link opening now exposes a named icon-only button, and capture card actions expose identifiers. A visible delete action was also added to capture cards for Workflow 5.

### Verification After Adjustments

- `make test` passed: 359 tests.
- `./scripts/qa.sh` passed: 29 tests.
