# T001 Scout: UI Automation Reliability Map

## `make ui-test` Reproduction

Command:

```text
make ui-test
```

Result: failed before any test body executed.

Key output:

```text
Failed to initialize for UI testing: Error Domain=com.apple.dt.XCTest.XCTFuture Code=1000 "Timed out while enabling automation mode."
RedditReminderUITests-Runner ... encountered an error (The test runner failed to initialize for UI testing. (Underlying Error: Timed out while enabling automation mode.))
```

Result bundle:

```text
build/Logs/Test/Test-RedditReminderUITests-2026.05.16_05-13-12--0700.xcresult
```

`xcresulttool` confirms the top-level action failed with the same initialization error, before per-test failures were reported.

Interpretation: current failure is at the XCUITest runner automation initialization boundary, consistent with local macOS automation/TCC setup. It is not evidence of a failing app assertion.

## Existing XCUITest Coverage

Files:
- `Tests/RedditReminderUITests/RedditReminderSmokeUITests.swift`
- `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift`

Current coverage:
- Launches with `--seed-qa`.
- Keyboard New Capture route opens and `captureWindow.title` exists.
- Keyboard Preferences route opens and `preferences.tab.General` exists.
- New Capture route exposes save/cancel buttons.
- Preferences General, Notifications, Backup tab buttons exist/click.
- Delete confirmation appears from a seeded capture card context menu, using fragile text matching for capture lookup.

Gaps versus critical UX QA flows:
- Invalid link inline validation is not covered by XCUITest.
- Planner row create context is not covered by XCUITest.
- No-channel Add channel draft recovery is not covered by XCUITest.
- Posted open/restore/delete actions are not covered by XCUITest.
- Existing tests duplicate setup and do not share launch/wait helpers.

## Stable Identifiers Available

Useful existing identifiers:
- Capture form: `captureWindow.title`, `captureWindow.text`, `captureWindow.links.newLink`, `captureWindow.links.add`, `captureWindow.links.validation`, `captureWindow.save`, `captureWindow.cancel`, `captureWindow.addChannel`, `captureWindow.noChannels`.
- Planner: `popover.header.planner`, `planner.createCapture`, `planner.createCapture.<subreddit-uuid>`, `planner.viewQueue`, `planner.editChannels`.
- Posted: `popover.header.posted`, `postedList.openPostedLink`, `postedList.restore`, `postedList.delete`.
- Header/search: `popover.header.settings`, `popover.header.newCapture`, `popover.search.clear`.
- Preferences/channels: `preferences.tab.<name>`, `channels.addSubreddit.textField`, `channels.addSubreddit.button`.

## Missing Or Risky Testability

- `make ui-test` cannot execute until automation mode initializes; this likely needs local macOS permission cleanup outside repo code.
- Existing UI tests use duplicated app launch/wait logic.
- Existing delete-confirmation test finds capture text with `label CONTAINS[c] "capture"` instead of a stable capture-card identifier.
- No dedicated no-channel test launch mode is currently confirmed. A reliable no-channel draft recovery XCUITest may require a narrow test-only launch flag or QA fixture mode.
- Planner context assertion may need a deterministic seeded channel identifier or an assertion based on save requirements disappearing after entering title/text.

## Recommended First Worker Slice

Because the runner failure is pre-test environment behavior, the first repo-side Worker should not attempt a broad product fix. Recommended first slice:

- Add/refactor XCUITest harness helpers for launch, route opening, and stable waits.
- Add focused tests that target already exposed stable identifiers for invalid link validation, planner create context, and posted action reachability.
- Record the runner timeout as an environment blocker if repeated `make ui-test` still cannot initialize.

Candidate allowed files:
- `Tests/RedditReminderUITests/RedditReminderSmokeUITests.swift`
- `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift`
- `Tests/RedditReminderUITests/RedditReminderUXFlowUITests.swift`
- `Tests/RedditReminderUITests/RedditReminderUITestSupport.swift`

Likely app-side follow-up if needed:
- Add a narrow no-channel QA launch flag and/or stable capture-card identifiers. This should be a separate Worker slice if tests cannot be reliable without app changes.
