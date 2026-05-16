# RedditReminder UX Quantitative Plan

## Objective

Create and execute a full UX roadmap for RedditReminder with rigorous, quantitative acceptance criteria. The roadmap must cover first-run trust, planner/editorial workflow, native macOS polish, accessibility, validation/error feedback, and gated architecture decisions.

## Original Request

"make a detailed plan with rigorous and quantitative acceptace criteria"

## Intake Summary

- Input shape: `vague`
- Audience: RedditReminder owner, future GoalBuddy PM, and implementation agents
- Authority: `requested`
- Proof type: `test`
- Completion proof: A final audit maps implemented UX roadmap slices to measurable UI behavior, executable or scripted tests/QA steps, pass/fail thresholds, explicit non-goals, and verification receipts proving the full UX tranche is complete.
- Likely misfire: GoalBuddy produces generic UX advice, subjective visual tweaks, or isolated fixes without source validation, quantitative acceptance criteria, and end-to-end verification.
- Blind spots considered: visual board selected; intent target resolved as full UX roadmap; success proof resolved as testable implementation criteria; tranche handling resolved as plan plus full execution; scope resolved by gating large architecture changes; goal handling resolved as a fresh goal.
- Existing plan facts: prior independent critiques identified planner/month view, native macOS polish, first-run notification timing, empty queue recovery, contextual planner actions, typography/hit-targets, and subreddit verification as candidate themes.

## Goal Kind

`open_ended`

## Current Tranche

The next `/goal` run should validate the prior UX critique against the current source, rank roadmap items by impact and testability, implement successive safe UX slices, verify each slice with tests or deterministic QA, gate large architecture changes behind Judge approval, and keep going until a final audit proves the UX tranche is complete.

This is not a planning-only goal. The plan is required, but completion also requires implementation and verification receipts unless a specific task is blocked with a durable receipt and a safe local workaround has been exhausted.

## Quantitative Acceptance Standard

Every implemented roadmap item must include all of the following before it can count as complete:

- A measurable user-visible behavior, such as "permission prompt is not requested at launch" or "empty queue CTA is visible when queued capture count is 0 and upcoming window count is greater than 0."
- A deterministic verification method: unit test, SwiftUI/view test, UI test, CLI check, scripted QA step, or source-backed assertion.
- A pass/fail threshold. Examples: zero launch-time notification permission requests, at least one visible CTA in a named empty state, minimum 28x28 pt hit frame for touched icon-only controls, no core newly touched action label below 11 pt unless Judge records an exception.
- A regression guard proving the prior happy path still works.
- A receipt listing changed files, verification commands, and result.

Subjective statements like "looks cleaner," "feels better," or "more native" are not sufficient unless converted into observable UI behavior and checked by a deterministic test or QA step.

## Non-Negotiable Constraints

- During `$goal-prep`, edit only this goal directory and generated visual board files.
- During `/goal`, implementation may occur only through active Worker or PM tasks with explicit allowed files.
- Preserve the prior critique themes as candidate inputs, but require Scout/Judge validation before execution.
- Acceptance criteria must be measurable, testable, or auditable, not subjective-only.
- Large architecture changes require Judge approval before implementation, including new windows/scenes, major navigation restructuring, and data model changes.
- Prefer existing SwiftUI/AppKit, SwiftData, test, and CLI patterns already present in the repo.
- Do not require live Reddit/network availability for automated test success.

## Roadmap Themes To Validate

- First-run trust and recovery: notification permission timing, first launch discoverability, no-captures-with-windows empty state, and no-channel capture recovery.
- Planner/editorial workflow: contextual planner actions, clearer 7-day calendar cells, queue readiness, and a gated decision on month/wider planner surfaces.
- Native macOS polish: appropriate button affordances, semantic typography, less overuse of tiny plain orange text, and clearer app/window boundaries.
- Accessibility: icon-only labels/help, deterministic identifiers, hit target minimums, keyboard/VoiceOver-friendly feedback.
- Validation and error feedback: invalid links, media failures, subreddit/channel validation, and inline error surfacing.
- Architecture decisions: native Settings/window migration, detachable/month planner, major navigation changes, and data model changes only after Judge approval.

## Stop Rule

Stop only when a final Judge or PM audit proves the full original outcome is complete.

Do not stop after planning, discovery, or Judge selection if a safe Worker task can be activated.

Do not stop after a single verified Worker package when the broader UX tranche still has safe local follow-up work. Advance the board to the next highest-leverage safe Worker package and continue unless a phase, risk, rejected-verification, ambiguity, or final-completion review is due.

## Canonical Board

Machine truth lives at:

`docs/goals/ux-quantitative-plan/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins for task status, active task, receipts, verification freshness, and completion truth.

## Run Command

```text
/goal Follow docs/goals/ux-quantitative-plan/goal.md.
```
