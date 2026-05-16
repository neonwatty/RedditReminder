# T006 Next Slice Decision

Decision: fixture slice plus UI test coverage.

Rationale:
- T003 proved the UI runner can pass locally after helper cleanup.
- Planner context cannot be deterministic with the current QA seed because every visible seeded planner window may already have matching queued captures, causing `planner.viewQueue` instead of `planner.createCapture.*`.
- No-channel draft recovery can use the existing `--clear-qa` launch argument and existing `captureWindow.addChannel`/Channels identifiers, so it does not need a new fixture.
- Delete confirmation should stay deferred. Both the queued-card menu path and posted delete button path produced accessibility snapshot hangs during XCUITest. Fixing that belongs in a narrower destructive-hit-target task after planner/no-channel coverage lands.

Selected Worker task: T004

Allowed files:
- `Sources/Utilities/QAFixtures.swift`
- `Tests/RedditReminderTests/QAFixturesTests.swift`
- `Tests/RedditReminderUITests/RedditReminderUITestSupport.swift`
- `Tests/RedditReminderUITests/RedditReminderUXFlowUITests.swift`

Worker objective:
- Add one QA planner fixture that guarantees at least one upcoming posting window has zero matching queued captures.
- Add UI automation for planner create-from-window context using `planner.createCapture.*`.
- Add UI automation for no-channel draft recovery using `--clear-qa`, `captureWindow.addChannel`, and Channels identifiers.

Verify:
- `make test`
- `make ui-test`
- GoalBuddy state checker.

Stop if:
- A required flow needs files outside the allowed list.
- The no-channel flow cannot be driven through existing Channels identifiers.
- XCUITest destructive button/alert snapshot hangs recur in non-destructive flows.

Full outcome complete: false
