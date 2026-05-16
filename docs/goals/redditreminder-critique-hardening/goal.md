# RedditReminder Critique Hardening

## Objective

Turn the three-agent critique into a sequenced, verified development effort that fixes the highest-risk RedditReminder UX, functionality, and CI/test-coverage gaps.

## Original Request

Create a detailed plan with clear acceptance criteria for each finding so development can be driven with GoalBuddy.

## Intake Summary

- Input shape: `existing_plan`
- Audience: RedditReminder maintainer and future GoalBuddy PM/Scout/Judge/Worker agents
- Authority: `requested`
- Proof type: `test`
- Completion proof: The board's implementation tasks are completed or explicitly blocked with receipts, each accepted issue has passing targeted verification, CI coverage is updated for the relevant behavior, and a final audit maps fixes back to the critique findings.
- Likely misfire: GoalBuddy could produce a polished plan but stop before implementing and verifying the product fixes.
- Blind spots considered: UI-test data isolation before CI enablement, destructive data-loss risks, multi-subreddit state consistency, CLI/app parity, and avoiding broad unrelated refactors.
- Existing plan facts: Three independent reviews identified priority findings across UX/workflow, features/functionality, and tests/CI. The most important findings are notification over-posting, UI tests absent from CI and unsafe against real data, unsaved edit loss when adding channels, unconfirmed cascading project deletion, stale per-subreddit posting state after edits, destination-less CLI captures, missing CLI partial-post parity, first-subreddit-only Reddit submit flow, unenforced coverage, misleading optional labels, missing in-app subreddit verification, weak project failure feedback, and brittle recipe search.

## Goal Kind

`existing_plan`

## Current Tranche

Complete successive safe verified slices until the accepted critique findings are either fixed with tests or intentionally deferred with a recorded rationale. Start by validating and operationalizing the critique into bounded work packages, then implement the highest-risk correctness and data-safety fixes before CI/test hardening and lower-priority UX parity work.

## Non-Negotiable Constraints

- Work only from board tasks; do not implement without an active Worker task.
- Preserve user data and avoid destructive commands.
- UI tests must use isolated storage before they can be added to CI.
- Prefer existing app and CLI patterns over broad rewrites.
- Keep fixes scoped to the critique findings unless a blocker requires a small adjacent change.
- Every Worker task must include targeted verification and update or add tests appropriate to the risk.
- Do not mark the goal complete while required Worker tasks remain queued, active, or unverified.

## Acceptance Criteria Summary

Each accepted finding has task-level acceptance criteria in `state.yaml`. In general, a finding is accepted only when:

- The user-visible behavior is corrected or the risk is explicitly deferred.
- Relevant unit, CLI, UI, or workflow tests cover the corrected behavior.
- Existing smoke checks still pass.
- Final audit confirms the behavior against concrete file/test evidence.

## Stop Rule

Stop only when a final audit proves the full original outcome is complete.

Do not stop after planning, discovery, or Judge selection if safe Worker tasks can be activated.

Do not stop after one verified Worker package when the broader critique hardening outcome still has safe local follow-up work. Advance the board to the next highest-leverage safe Worker package and continue unless a phase, risk, rejected-verification, ambiguity, or final-completion review is due.

## Slice Sizing

Safe means bounded, explicit, verified, and reversible. It does not mean tiny.

A good Worker task should complete a coherent product slice, such as cross-post state correctness, UI-test isolation plus CI enablement, destructive-action safety, or CLI parity.

## Canonical Board

Machine truth lives at:

`docs/goals/redditreminder-critique-hardening/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins for task status, active task, receipts, verification freshness, and completion truth.

## Run Command

```text
/goal Follow docs/goals/redditreminder-critique-hardening/goal.md.
```

## PM Loop

On every `/goal` continuation:

1. Read this charter.
2. Read `state.yaml`.
3. Run the bundled GoalBuddy update checker when available and mention a newer version without blocking.
4. Work only on the active board task.
5. Assign Scout, Judge, Worker, or PM according to the task.
6. Write a compact task receipt.
7. Update the board.
8. Continue to the next safe local task unless a final audit proves completion.
