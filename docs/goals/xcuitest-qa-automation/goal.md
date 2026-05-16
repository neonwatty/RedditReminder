# RedditReminder XCUITest QA Automation

## Objective

Stabilize RedditReminder UI automation and add focused XCUITest coverage for the critical UX QA flows from the completed UX tranche.

## Original Request

`$goalbuddy:goal-prep this`

## Intake Summary

- Input shape: `existing_plan`
- Audience: RedditReminder owner and future implementation agents
- Authority: `requested`
- Proof type: `test`
- Completion proof: `make ui-test` passes twice consecutively after focused critical-flow XCUITest coverage is added, and `make test` passes.
- Likely misfire: adding brittle UI tests without first resolving the UI test runner timeout, or treating unit/static coverage as equivalent to XCUITest coverage for critical manual QA flows.

## User Choices

- Visual board: local live board.
- Outcome target: runner reliability plus critical UX flow coverage.
- Success proof: `make ui-test` passes twice plus `make test` passes.
- Scope: no broad app redesign or architecture changes; narrow testability hooks, accessibility identifiers, and QA fixture changes are allowed.
- Goal handling: fresh focused goal.

## Existing Plan To Validate

1. Stabilize `make ui-test` first.
2. Add reusable UI test harness helpers for launch, waiting, route opening, and stable identifiers.
3. Automate critical capture validation, planner context, no-channel draft recovery, and posted recovery flows where feasible.
4. Keep non-UI behavior in unit/static tests when XCUITest would be fragile.
5. Verify with `make test`, `make ui-test`, and a second consecutive `make ui-test`.

## Non-Negotiable Constraints

- Do not make broad product redesigns, new scenes/windows, or architecture changes for this goal.
- Prefer stable accessibility identifiers over visible text matching where identifiers exist or can be added narrowly.
- Use seeded QA data or test-only launch modes; do not mutate the user's real app data during UI tests.
- Distinguish environment-only macOS automation permission failures from repo-side failures.
- Preserve existing unit/static coverage as the source of truth for non-UI invariants such as launch notification request behavior, hit-target constants, helper formatting, and media filtering.

## Current Tranche

The `/goal` run should first discover and classify the current UI test runner failure, then choose the largest safe useful implementation slice. It should continue through runner reliability, harness cleanup, focused critical-flow XCUITest coverage, repeated verification, and final audit unless a specific task is blocked with exact environment evidence.

## Quantitative Acceptance Standard

The goal is complete only when:

- `make test` passes.
- `make ui-test` passes twice consecutively after the new/updated XCUITests are present.
- If `make ui-test` cannot run because of local macOS automation permissions or another environment-only condition, the blocker receipt includes exact failure output, the repo-side coverage work that was completed, and remaining manual-only QA items.
- The final audit maps each critical UX QA flow to XCUITest coverage, unit/static coverage, or a documented manual-only blocker.

## Critical UX QA Flows

- New Capture opens and can save/cancel.
- Invalid link shows inline error and preserves input; valid link clears the error.
- Planner row `Create capture` opens capture with channel/subreddit context.
- No-channel `Add channel` preserves draft state across route change.
- Posted open/restore/delete actions are reachable, and restore behavior is verified if seeded data supports it.

## Stop Rule

Stop only when a final Judge or PM audit proves the full original outcome is complete, or when the only remaining blocker is environment-only and recorded with exact evidence.

Do not stop after planning, discovery, a single UI test file change, or a passing unit suite if the required UI test verification is still possible.

## Canonical Board

Machine truth lives at:

`docs/goals/xcuitest-qa-automation/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins.

## Run Command

```text
/goal Follow docs/goals/xcuitest-qa-automation/goal.md.
```
