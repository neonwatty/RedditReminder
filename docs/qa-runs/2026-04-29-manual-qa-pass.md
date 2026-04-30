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

Status: Passed after visual/manual posted-history pass.

### Steps Exercised

- [x] Marked a deterministic queued capture as posted with a saved Reddit URL through the debug QA menu.
- [x] Confirmed the posted record summary includes title, body, subreddit, and saved URL.
- [x] Copied the saved posted URL for verification.
- [x] Marked another deterministic queued capture as posted with no URL.
- [x] Confirmed posted history records the capture without showing a broken link value.
- [x] Complete a visual/manual pass through the popover Posted tab.
- [x] Open the saved Reddit URL from the posted-history UI.

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

Popover Posted tab manual pass:

```text
Header/footer: RedditReminder / 8 posted
Newest posted row: QA Workflow Capture
Body: Created by RedditReminder automated QA.
Subreddit: r/SideProject
Metadata: relative posted time plus "link saved"
Saved URL action: opened from the posted-history row
Browser result: Google Chrome opened a reddit.com comments URL for the saved qa123 test link
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

## Workflow 5 - Delete Safety

Status: Passed.

### Steps Exercised

- [x] Created a disposable queued capture titled `QA Workflow Capture` through the debug QA menu.
- [x] Clicked the capture-card delete action in the popover Queue tab.
- [x] Cancelled the native delete confirmation.
- [x] Confirmed the disposable capture remained queued.
- [x] Clicked delete again and confirmed.
- [x] Confirmed the disposable capture was removed.

### Evidence

Database verification after cancelling delete:

```sql
select count(*)
from ZCAPTURE
where ZTITLE = 'QA Workflow Capture'
  and ZSTATUS = 'queued';
```

Observed:

```text
1
```

Database verification after confirming delete:

```text
0
```

### Findings

No product issue found in the delete safety workflow. The confirmation alert prevents accidental deletion, and confirmed deletion removes the queued capture.

### Local QA Environment Notes

- `make test` initially required `xcodegen`; installing `xcodegen` fixed project generation.
- Standard `make test` and `make install-debug` hit local signing/keychain failures with the Apple Development identity (`errSecInternalComponent`).
- A local QA build succeeded with ad-hoc signing and `ENABLE_DEBUG_DYLIB=NO`:

```sh
xcodebuild build \
  -project RedditReminder.xcodeproj \
  -scheme RedditReminder \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= \
  ENABLE_DEBUG_DYLIB=NO \
  OTHER_CODE_SIGN_FLAGS=
```

- `./scripts/qa.sh` was run directly against that installed debug build. The posted QA hooks passed, but the script reported 7 window-detection failures on this host because the capture/preferences windows were exposed without the expected CG window names.

## Workflow 6 - Planner

Status: Passed with local accessibility caveat.

### Steps Exercised

- [x] Opened Settings with `Cmd+,`.
- [x] Opened the Planner tab in Preferences.
- [x] Confirmed Planner renders the 7-day planner view from the Preferences window.
- [x] Confirmed Planner rows are backed by upcoming subreddit events grouped through `PlannerPresentation.dayGroups`.
- [x] Confirmed row presentation includes event/subreddit title, short time, queue readiness, and Auto/Manual status in `PlannerTabView`.
- [x] Added a disposable queued capture for `r/SideProject`.
- [x] Returned to Planner data and confirmed readiness increased.
- [x] Deleted the disposable capture.
- [x] Confirmed readiness decreased again.

### Evidence

Preferences window opened:

```text
RedditReminder Preferences
Size: 500 x 472
```

Planner readiness count for `r/SideProject` before adding the disposable capture:

```text
14
```

After `QA > Create Test Capture`:

```text
15
```

After `QA > Delete Test Captures`:

```text
14
```

Disposable capture cleanup:

```text
QA Workflow Capture remaining: 0
```

### Findings

No product issue found in Planner readiness updates. Adding a queued capture for a listed subreddit increments readiness, and deleting that capture decrements readiness.

Local accessibility caveat: the Planner tab can be selected and rendered, but recursively extracting SwiftUI static text from the Preferences window hung on this host. The visual row-content expectations were verified against the active Planner implementation and store-backed readiness changes rather than a full Accessibility text dump.

## Workflow 7 - Backup And Restore

Status: Passed with service-level restore verification and local UI caveat.

### Steps Exercised

- [x] Confirmed Preferences exposes the Backup tab.
- [x] Selected the Backup tab in Preferences.
- [x] Verified backup export/import through `BackupService` full-suite coverage.
- [x] Verified export includes a subreddit posting checklist.
- [x] Verified export includes a queued/posted capture with title, body, links, notes, project, and subreddit relationships.
- [x] Verified export includes a posted capture URL.
- [x] Imported the backup into a disposable destination store.
- [x] Confirmed imported data replaced pre-existing destination data.
- [x] Confirmed capture title, posted URL, checklist, capture status, project, subreddit, event, and settings survived restore.
- [x] Confirmed embedded media export/import tests pass.

### Evidence

Full test suite run with local signing overrides:

```text
Test run with 359 tests in 1 suite passed
```

Backup-specific passing tests observed in `/tmp/redditreminder-full-adhoc-tests.log`:

```text
backupRoundTripsDataAndSettings passed
backupPreviewReturnsCountsWithoutMutatingData passed
backupExportEmbedsExistingMediaFiles passed
backupImportRestoresEmbeddedMediaFiles passed
backupImportRejectsMissingRelationships passed
backupImportFailurePreservesExistingData passed
backupImportFailurePreservesExistingSettings passed
```

Round-trip fixture details:

```text
Project: Launch
Subreddit: r/SwiftUI
Checklist:
Use the weekly thread flair.
Include a demo link.
Capture title: Launch title
Capture body: Post draft
Capture status: posted
Posted URL: https://www.reddit.com/r/SwiftUI/comments/abc
Destination store: disposable test container with old data replaced
```

### Findings

No product issue found in backup service behavior. The backup round trip preserves checklist content, capture status, posted URL, relationships, events, and backed-up settings, and import replaces existing destination data.

Local UI caveat: the Backup tab is selectable in Preferences, but macOS file exporter/importer panels are not reliable to drive in this automation environment. Restore was verified through the same production `BackupService` path using disposable test stores rather than through manual file picker clicks.

## Workflow 8 - Keyboard Shortcuts

Status: Passed with CG-window-name caveat.

### Steps Exercised

- [x] Launched the debug QA build.
- [x] Pressed `Cmd+N`.
- [x] Confirmed a `New Capture` window opens.
- [x] Pressed `Cmd+,`.
- [x] Confirmed `RedditReminder Preferences` opens.
- [x] Pressed `Cmd+N` repeatedly with an existing capture window.
- [x] Confirmed only one `New Capture` window remains.
- [x] Pressed `Cmd+,` repeatedly with Settings already open.
- [x] Confirmed only one Preferences window remains.
- [x] Opened the menu-bar popover.
- [x] Pressed `Cmd+N` while the popover was open.
- [x] Confirmed the popover dismissed and one capture window opened.
- [x] Opened the menu-bar popover again.
- [x] Pressed `Cmd+,` while the popover was open.
- [x] Confirmed the popover dismissed and one Preferences window opened.

### Evidence

`Cmd+N` result:

```text
New Capture|AXWindow|750,127|420x572
```

`Cmd+,` result:

```text
RedditReminder Preferences|AXWindow|710,152|500x472
```

Duplicate prevention after repeated shortcuts:

```text
captureCount=1
prefsCount=1
```

`Cmd+N` while popover was open:

```text
popoverVisibleBefore=true
captureCount=1
popoverVisibleAfter=false
```

`Cmd+,` while popover was open:

```text
popoverVisibleBefore=true
prefsCount=1
popoverVisibleAfter=false
```

### Findings

No product issue found in keyboard shortcut behavior. `Cmd+N` and `Cmd+,` open the expected windows, reuse existing windows instead of duplicating them, and dismiss the menu-bar popover when launched from an open popover.

Local caveat: CoreGraphics reports the app windows with nil names on this host, so window identity was verified through Accessibility window names and popover visibility was verified through the layer-25 CoreGraphics popover check used by `scripts/qa.sh`.

## Workflow 9 - Relaunch Persistence

Status: Passed with local checklist setup caveat.

### Steps Exercised

- [x] Launched the debug QA build with seeded data.
- [x] Created a deterministic queued capture titled `QA Workflow Capture`.
- [x] Created and marked another deterministic capture posted with a saved Reddit URL.
- [x] Added a deterministic posting checklist to `r/SideProject` while the app was closed.
- [x] Relaunched the app normally, without `--seed-qa`.
- [x] Confirmed the queued capture persisted.
- [x] Confirmed posted history persisted with the saved posted URL.
- [x] Confirmed checklist content persisted.
- [x] Confirmed planner backing data persisted.
- [x] Opened the popover after relaunch.

### Evidence

Before relaunch:

```text
r/SideProject checklist:
Use the weekly thread flair.
Include the launch link.

QA Workflow Capture|posted|https://www.reddit.com/r/SideProject/comments/qa123/reddit_reminder_qa/
QA Workflow Capture|queued|
```

After relaunch:

```text
r/SideProject checklist:
Use the weekly thread flair.
Include the launch link.

QA Workflow Capture|posted|https://www.reddit.com/r/SideProject/comments/qa123/reddit_reminder_qa/
QA Workflow Capture|queued|
```

Posted history copied from the running app after relaunch:

```text
Title: QA Workflow Capture
Body: Created by RedditReminder automated QA.
Subreddit: r/SideProject
Posted URL: https://www.reddit.com/r/SideProject/comments/qa123/reddit_reminder_qa/
```

Queue copied from the running app after relaunch:

```text
QA Workflow Capture
```

Planner backing data after relaunch:

```text
r/SideProject queued readiness count: 23
r/SideProject active planner events: 48
popoverVisible=true
```

### Findings

No product issue found in relaunch persistence. Queue, posted history, posted URL, checklist content, and planner data were still available after a normal app relaunch.

Local setup caveat: checklist content was inserted while the app was closed because this environment’s SwiftUI row text/editing accessibility is too brittle for reliable checklist entry automation. Persistence was verified from the store after relaunch.

## Workflow 10 - Edge Cases

Status: Passed with deterministic model/rendering coverage and local visual caveat.

### Steps Exercised

- [x] Created a capture with title only.
- [x] Created a capture with body only.
- [x] Created a capture with a long title.
- [x] Created a capture with a long body.
- [x] Created a capture assigned to multiple subreddits.
- [x] Added checklist content with blank lines and whitespace-only lines.
- [x] Confirmed blank checklist lines are removed before rendering the handoff checklist.
- [x] Confirmed long content is constrained by the queue and handoff views instead of expanding controls offscreen.

### Evidence

Full test suite after adding Workflow 10 coverage:

```text
Test run with 365 tests in 1 suite passed
** TEST SUCCEEDED **
```

New deterministic coverage:

- `titleOnlyCapturePersists`
- `bodyOnlyCapturePersists`
- `longTitleAndBodyPersistUnchanged`
- `captureAssignedToMultipleSubredditsPersists`
- `postingChecklistItemsRemoveBlankLinesAndTrimWhitespace`
- `postingChecklistItemsEmptyInputReturnsEmptyList`

Checklist cleanup example covered by tests:

```text
raw: ["", "  Confirm title formatting  ", "", "Attach launch screenshot", "   "]
cleaned: ["Confirm title formatting", "Attach launch screenshot"]
```

Long-text rendering constraints verified in code:

- `CaptureCardView` limits queue title/body text to one/two lines.
- `PostHandoffView` limits handoff body text to eight lines and notes to five lines inside fixed-width fields.
- Checklist rows use wrapping text, so long checklist items can grow vertically without pushing horizontal controls offscreen.

### Findings

No product issue found in the edge-case data paths. Title-only, body-only, long-title, long-body, and multi-subreddit captures persist successfully, and blank checklist lines are filtered out before handoff rendering.

Local visual caveat: screen capture is unavailable in this environment and broad SwiftUI Accessibility traversal can hang, so clipping/overlap risk was verified through deterministic model tests plus the view constraints above rather than screenshot evidence.

## Final Setup Verification - 2026-04-30

Status: Automated unit, format, build, and UI smoke checks passed.

### Commands Run

- [x] Installed `swift-format` locally with Homebrew so the repo format script can run.
- [x] Ran `./scripts/format-check.sh`.
- [x] Ran the full test suite with local ad-hoc signing overrides.
- [x] Built and installed the debug app with local ad-hoc signing overrides.
- [x] Updated `./scripts/qa.sh` to use Accessibility for app-window title/size checks, because CoreGraphics can report nil window names for SwiftUI windows on this host.
- [x] Ran `./scripts/qa.sh` against the installed debug app.

### Evidence

Format check:

```text
swift-format warnings: 4198 (baseline: 5511)
```

Full test suite:

```text
Test run with 365 tests in 1 suite passed
** TEST SUCCEEDED **
```

Debug build:

```text
** BUILD SUCCEEDED **
```

QA smoke script:

```text
ALL 29 TESTS PASSED
```

Passing QA-script coverage included launch, popover toggle, New Capture, Preferences, popover auto-dismiss, capture window reuse, Preferences window reuse, seeded popover rendering, debug capture creation, queued capture copy, submit URL copy, mark posted, posted summary with URL, posted URL copy, posted summary without URL, restart, popover open after restart, and New Capture after restart.

### Findings

No new product issue found from the final verification pass. The deterministic unit coverage, format check, debug build, and full QA smoke script all pass.
