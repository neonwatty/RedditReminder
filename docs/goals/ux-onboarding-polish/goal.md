# RedditReminder UX Onboarding Polish

## Objective

Improve the current RedditReminder macOS menu bar app UX by implementing a focused first tranche from the independent UX critiques. This tranche prioritizes first-run clarity: make setup order understandable, prevent the zero-subreddit capture-creation dead end, expose channel setup, and explain disabled Save states. Light visual polish is allowed where it directly supports these first-run changes.

## Original Request

Create a detailed plan plus acceptance criteria for the UX critique work so development can be driven using `/goal` and GoalBuddy.

## Intake Summary

- Input shape: `existing_plan`
- Audience: RedditReminder users, especially first-time users and repeat power users managing captures from the menu bar.
- Authority: `requested`
- Proof type: `test | review`
- Completion proof: Focused tests and existing verification pass where practical, and a final audit maps implemented changes to the first-run clarity acceptance criteria with no unrelated worktree changes.
- Likely misfire: GoalBuddy produces only a plan or cosmetic tweaks while leaving the first-run dead end and hidden primary actions unresolved.
- Blind spots considered:
  - The critiques were source-based; no local screenshots/assets were available.
  - A broad redesign could sprawl. This tranche should prioritize high-impact, reversible improvements.
  - macOS-native fit matters, but should not override functional clarity.
- Existing plan facts:
  - Three independent critiques were collected: first-time onboarding, macOS visual/platform fit, and power-user workflow/accessibility.
  - Top themes: first-run setup dead end, Channels hidden inside Settings, hover-only queue actions, linear capture form, cramped settings tabs, over-custom chrome, small typography/targets, non-scaling subreddit picker, busy channel rows, weak empty-state recovery actions.
  - Owner chose first-run clarity as the tranche priority.
  - Owner chose tests plus code review as the proof standard.
  - Owner allowed light visual polish where touched by first-run work, while broad redesign remains out of scope.

## Goal Kind

`existing_plan`

## Current Tranche

Drive a focused first-run clarity implementation tranche. Preserve the critique findings as input, validate the exact files and test commands, choose the largest safe useful slices, implement them, verify them with tests plus code review, then run a final audit against the acceptance criteria. Do not stop after planning if a safe Worker task exists.

## Non-Negotiable Constraints

- Keep the app a compact macOS menu bar utility unless the board explicitly discovers that a separate preferences window is required and safe.
- Prefer existing SwiftUI/AppKit patterns in this repo.
- Do not rewrite unrelated architecture or data models unless directly required by an accepted UX slice.
- Do not remove existing QA/accessibility identifiers unless replaced with equivalent or better coverage.
- Allow small typography, spacing, button affordance, target-size, and semantic-color improvements only when they are adjacent to the first-run clarity slice being implemented.
- Defer full settings redesign, bulk triage, complete visual system overhaul, and broad queue workflow changes unless a Judge explicitly determines a small part is necessary to satisfy first-run acceptance criteria.
- Do not revert unrelated user changes.
- Keep changes verifiable with existing repo commands where possible.

## Stop Rule

Stop only when a final audit proves the full original outcome is complete.

Do not stop after planning, discovery, or Judge selection if the user asked for working software or automation and a safe Worker task can be activated.

Do not stop after a single verified Worker package when the broader owner outcome still has safe local follow-up work. Advance the board to the next highest-leverage safe Worker package and continue unless a phase, risk, rejected-verification, ambiguity, or final-completion review is due.

Do not create one Worker/Judge pair per repeated file, table, route, or helper. Put repeated same-shape work into one Worker package and review the package as a whole.

## Acceptance Criteria

1. First-run setup no longer dead-ends:
   - When there are zero subreddits/channels, the primary empty-state action routes users toward adding a subreddit/channel before creating a capture.
   - The capture form clearly explains the minimum save requirements when Save is disabled.
   - Users can reach channel setup from the zero-state without hunting behind a generic gear-only path.

2. Onboarding communicates setup order:
   - The empty state presents the required sequence: add subreddit/channel, create capture, enable reminders/notifications.
   - At least the first required step is actionable from that state.
   - Copy remains concise enough for the 460pt popover.

3. Queue actions are discoverable and efficient:
   - At least one primary capture action is visible without hover.
   - Secondary actions remain available through visible controls or menu/context fallback.
   - Keyboard/accessibility users can discover and invoke the same core actions.

4. Capture creation is faster and clearer:
   - Title/body/subreddit remain visually prioritized over optional project, notes, links, and media.
   - Save/Cancel behavior is easy to find during scrolling, or the board records why sticky actions are deferred.
   - Existing create/edit behavior and persistence continue to work.

5. Settings/channel complexity is reduced for the first tranche:
   - Core channel setup is easier to discover.
   - Advanced channel timing controls are less overwhelming or more clearly grouped, unless Judge explicitly defers this with rationale.
   - Preferences navigation remains usable at 460pt width.

6. Styling/accessibility improves without a full redesign:
   - The tranche reduces the most obvious over-custom or cramped styling issues in surfaces touched by first-run work.
   - Action target sizes and labels improve where touched.
   - Reddit orange is used more deliberately where touched, with semantic status colors where appropriate.
   - Full app-wide visual redesign is explicitly deferred.

7. Verification is explicit:
   - Existing relevant tests pass, or failures are documented as unrelated with evidence.
   - Any changed UI behavior has updated or added tests where the repo has suitable coverage.
   - Final audit maps each acceptance criterion to code changes and verification evidence.

## Canonical Board

Machine truth lives at:

`docs/goals/ux-onboarding-polish/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins for task status, active task, receipts, verification freshness, and completion truth.

## Run Command

```text
/goal Follow docs/goals/ux-onboarding-polish/goal.md.
```

## PM Loop

On every `/goal` continuation:

1. Read this charter.
2. Read `state.yaml`.
3. Run the bundled GoalBuddy update checker when available and mention a newer version without blocking.
4. Re-check the intake: original request, input shape, authority, proof, blind spots, existing plan facts, and likely misfire.
5. Work only on the active board task.
6. Assign Scout, Judge, Worker, or PM according to the task.
7. Write a compact task receipt.
8. Update the board.
9. If safe local work remains, choose the next largest reversible Worker package and continue unless blocked.
10. Review at phase, risk, rejected-verification, ambiguity, or final-completion boundaries; do not review every small Worker by habit.
11. Finish only with a Judge/PM audit receipt that maps receipts and verification back to the original user outcome and records `full_outcome_complete: true`.
