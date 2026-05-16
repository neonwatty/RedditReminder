# T004 Fixture And Critical Flows Receipt

Result: done

Changes:
- Added a QA-only `r/NoCaptureQA` subreddit and an upcoming `No Capture QA Window` with no queued matching captures.
- Updated QA fixture tests to assert the new deterministic planner window and no matching captures.
- Added a cleared-app launch helper for `--clear-qa`.
- Added XCUITest coverage for planner create-from-window context. The test opens Planner, triggers `planner.createCapture.*`, enters content, and proves Save is enabled, which requires the planner-selected subreddit context.
- Added XCUITest coverage for no-channel draft recovery. The test launches with `--clear-qa`, enters title/body/link draft content, routes through Add channel, creates the first channel, returns to capture, and asserts draft fields are preserved.

Verification:
- `make test`: passed at `2026-05-16 05:39:13 -0700`.
  - 435 tests passed.
  - Result bundle: `build/Logs/Test/Test-RedditReminder-2026.05.16_05-39-08--0700.xcresult`.
- `make ui-test`: passed at `2026-05-16 05:45:48 -0700`.
  - 8 UI tests executed.
  - 1 explicit skip remains for delete confirmation.
  - 0 failures.
  - Result bundle: `build/Logs/Test/Test-RedditReminderUITests-2026.05.16_05-44-02--0700.xcresult`.

Deferred:
- Destructive delete confirmation remains skipped because XCUITest still hangs while snapshotting the destructive hit path. This should be handled as a narrower hit-target/alert automation task.
- Posted restore behavior is still only covered as action reachability, not mutation, to avoid introducing another destructive-style click path before the hit-target issue is solved.
