# T002 Judge Decision: First UI Automation Slice

Decision: environment blocker plus test harness/coverage slice.

Rationale:
- `make ui-test` fails before any test body runs with `Timed out while enabling automation mode`.
- This is at the XCUITest runner initialization boundary, so a product-code fix is not justified as the first move.
- The repo still has useful local work: consolidate UI test helpers and add focused coverage against stable identifiers that already exist.

Selected Worker task: `T003`.

Allowed files:
- `Tests/RedditReminderUITests/RedditReminderUITestSupport.swift`
- `Tests/RedditReminderUITests/RedditReminderSmokeUITests.swift`
- `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift`
- `Tests/RedditReminderUITests/RedditReminderUXFlowUITests.swift`

Objective:
- Add shared XCUITest launch/route helpers.
- Refactor existing UI tests onto the helpers.
- Add focused tests for invalid link validation, planner create context, and posted action reachability using stable identifiers.
- Re-run `make ui-test` and record whether the same environment initialization blocker remains.

Verification:
- `make test`
- `make ui-test`
- GoalBuddy checker

Stop conditions:
- Need app/source changes outside the UI test target.
- UI tests require new QA launch flags or identifiers not already available.
- `make ui-test` gets past automation initialization and fails twice in app assertions for the same reason.

Full outcome complete: false.
