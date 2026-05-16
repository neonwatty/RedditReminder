# T002 Roadmap Decision

## Decision

Approved first Worker slice: first-run trust and queue recovery.

This slice is the largest safe useful first package because it addresses the highest-severity trust issue and a clear workflow dead end without new scenes, model changes, or major navigation restructuring.

## Prioritized Roadmap

### P0: First-run trust and empty queue recovery

- User outcome: launching the app must not burn notification permission before user intent, and users with posting windows but no drafts must see a clear next action.
- Acceptance:
  - Launch configuration causes exactly 0 notification authorization requests.
  - Explicit Notifications UI action remains the only permission request path.
  - Queue shows exactly 1 create-capture CTA when `displayedCaptures.count == 0`, `upcomingWindows.count > 0`, and no subreddit filter is active.
  - CTA is absent when queued captures are visible.
  - Unit/view tests prove static text, identifiers, and route logic.
- Risk: low; can be handled in `AppDelegate`, popover empty state, and focused tests.

### P1: Capture/channel recovery

- User outcome: a user who starts a capture before adding channels cannot lose draft work while recovering.
- Acceptance:
  - No-channel recovery keeps entered title/text/notes/link/media state or adds a channel inline.
  - Error/duplicate/normalized channel states are visible with stable identifiers.
  - At least two tests cover no-channel recovery and duplicate/invalid channel feedback.
- Risk: medium; route preservation may affect popover navigation state.

### P1: Planner actionability

- User outcome: planner actions carry context and visible calendar cells identify posting targets without hover-only dependence.
- Acceptance:
  - Planner create action carries selected event/subreddit context.
  - 7-day calendar visible text includes at least time plus subreddit/channel for non-empty windows.
  - Overflow has deterministic drill-in/filter behavior or explicitly deferred task.
  - Tests cover route context and multi-window day presentation.
- Risk: medium; may require form prefill state.

### P2: macOS polish/accessibility baseline

- User outcome: touched controls have native affordance, labels/help, and usable hit targets.
- Acceptance:
  - Touched icon-only controls have labels and help text.
  - Touched action controls use at least 28x28 pt frames or documented Judge exceptions.
  - No newly touched core action label below 11 pt unless compact exception is recorded.
  - At least three focused tests/assertions cover labels, identifiers, or sizing constants.
- Risk: medium-low; visual regressions need careful scope.

### P2: Validation and error feedback

- User outcome: invalid links and media import failures are visible and testable.
- Acceptance:
  - Invalid links render inline error with stable identifier.
  - File importer failure renders inline error with stable identifier.
  - Existing successful link/media tests continue passing.
  - At least two new tests cover invalid link and importer failure.
- Risk: low-medium; file importer failure is harder to simulate directly.

### P3/Gated: Architecture decisions

- User outcome: large ideas such as native Settings window or month/detachable planner are evaluated after smaller issues are fixed.
- Acceptance:
  - No new windows/scenes, major navigation restructuring, or data model changes before T008 Judge approval.
  - Any approved architecture slice has separate allowed files, tests, rollback plan, and manual QA criteria.
- Risk: high; defer until T008.

## First Worker Package

Task: T003 first-run trust and queue recovery.

Allowed files:

- `Sources/App/AppDelegate.swift`
- `Sources/Views/PopoverContentView.swift`
- `Sources/Views/PopoverContentEmptyStates.swift`
- `Tests/RedditReminderTests/AppDelegateSchedulingTests.swift`
- `Tests/RedditReminderTests/PopoverChromeViewTests.swift`
- `Tests/RedditReminderTests/PreferencesViewTests.swift`

Verification:

- `make test`
- `make ui-test` if unit tests pass and UI test runtime is practical
- `node /Users/neonwatty/.codex/plugins/cache/goalbuddy/goalbuddy/0.3.6/skills/goalbuddy/scripts/check-goal-state.mjs docs/goals/ux-quantitative-plan/state.yaml`

Stop if:

- The fix requires new windows/scenes, model changes, or major navigation restructuring.
- Queue CTA cannot be tested without broad SwiftUI view introspection changes.
- Notification permission removal breaks notification scheduling tests.
- Verification fails twice for the same reason.
