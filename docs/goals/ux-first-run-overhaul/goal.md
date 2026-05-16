# UX First-Run Overhaul

## Objective

Rebuild the RedditReminder menu bar app UX around a successful first-run path while also addressing the navigation, styling, accessibility, and visual-design critique from the three independent UX reviews.

The current tranche should produce working software, not only planning: a new user should be able to find the app, add a posting channel, create a first capture, understand posting windows, enable reminders, and use the queue without hidden or inaccessible controls.

## Original Request

Create a detailed plan to address each UX critique item and determine appropriate acceptance criteria and stopping conditions so the work can proceed through `/goal`.

## Intake Summary

- Input shape: `existing_plan`
- Audience: new and returning RedditReminder users on macOS, plus the developer using GoalBuddy to drive the work.
- Authority: `requested`
- Proof type: `test`, `demo`, `artifact`, and `review`
- Completion proof: automated verification passes, a local app walkthrough proves the first-run loop and core queue workflows, and a final Judge/PM audit maps every critique theme to completed work, an explicit deferral, or a blocked item with a reason.
- Likely misfire: GoalBuddy could polish isolated copy or styling while leaving the user unable to complete the first-run loop or while keeping core workflow areas buried inside Settings.
- Blind spots considered: scope can expand into a visual redesign without improving task success; menu bar popover constraints may make a full IA redesign riskier than a focused navigation split; accessibility fixes must be verified beyond visual inspection; app-store-style native macOS fit may conflict with custom Reddit branding if not intentionally resolved.
- Existing plan facts:
  - Three independent UX reviewers already critiqued first-run/task flow, information architecture/settings discoverability, and visual/accessibility/macOS fit.
  - User selected local live board.
  - User selected first-run completion as the primary optimization target.
  - User selected automated plus manual verification.
  - User allowed full visual redesign.
  - User selected a fresh GoalBuddy goal.

## Goal Kind

`existing_plan`

## Current Tranche

Complete successive safe verified slices until the app satisfies the UX critique:

1. Validate the plan against the current code and choose exact implementation boundaries.
2. Fix first-run routing and setup completion.
3. Rework the popover information architecture so workspace objects are not buried in Settings.
4. Make capture and row actions visible, keyboard reachable, and recoverable.
5. Redesign the visual system enough to resolve cramped controls, weak focus affordances, overloaded color semantics, and inconsistent settings surfaces.
6. Verify with automated tests, build/test commands, accessibility-oriented checks where feasible, and a local menu bar walkthrough.

## UX Plan And Acceptance Criteria

### 1. First-Run Completion

Address:

- First-run setup does not complete the loop.
- Notifications are mentioned but hidden.
- Capture creation dead-ends before channels exist.
- Timing concepts are visible but under-explained.

Acceptance criteria:

- Empty state presents a clear ordered path: add channel, create first capture, enable reminders.
- The primary first-run action deep-links to channel setup rather than generic settings.
- After adding the first channel, the UI exposes a clear next step to create the first capture.
- Capture creation with zero channels shows an inline recovery action to add a channel.
- The subreddit/channel requirement is visually marked as required near the relevant control and near Save feedback.
- After channel creation, the app explains that posting windows were generated and where to adjust them.
- Notification setup is reachable from the first-run path without hunting through unrelated settings.
- Tests cover routing/default-tab behavior, zero-channel capture guidance, and save requirement copy/state where practical.

Stopping conditions:

- Stop and ask the operator if the desired first-run sequence would require persistent onboarding state that is not already modeled and cannot be added safely in this tranche.
- Stop the current Worker slice if adding inline channel creation to the capture form requires a broad persistence or architecture rewrite outside the allowed files.
- Do not stop merely because notification permission cannot be granted automatically; record manual walkthrough proof and keep local UI work moving.

### 2. Information Architecture And Navigation

Address:

- Core workspace objects are buried inside Settings.
- Settings navigation is too flat for six destinations in a fixed popover.
- Planner is discoverable but not actionable.
- Duplicate lead-time settings create ambiguity.

Acceptance criteria:

- Channels, Planner, and Projects are exposed as workspace-level destinations or otherwise clearly separated from true app settings.
- Settings contains only app behavior/system preference surfaces such as notifications, backup, defaults, shortcuts, and app behavior.
- Navigation labels and ordering reflect the main loop: capture, queue, posting windows/planner, handoff, posted.
- Planner rows include explicit actions or routes for the next likely job, such as create capture, view queue, or edit channel windows.
- Duplicate lead-time controls are consolidated or one is converted to read-only explanatory/reference copy.
- Tests cover tab/default routing, settings section availability, and any moved/consolidated settings state.

Stopping conditions:

- Stop and ask the operator if the IA change requires removing a major feature from the popover or changing product scope.
- Stop the current Worker slice if navigation state becomes ambiguous enough that existing tests cannot establish the intended route.
- Defer only with a receipt if a workspace destination cannot be moved without risky broad rewiring; do not silently leave it buried.

### 3. Action Discoverability And Task Recovery

Address:

- Important actions are hidden behind hover, expansion, context menus, or drag only.
- Capture cards, project rows, and channel rows lack stable visible management affordances.
- Capture form hierarchy places required/save guidance too low.

Acceptance criteria:

- Capture cards expose a stable visible action path for prepare handoff and secondary actions such as copy, mark posted, and delete.
- Project rows expose visible management affordances or a stable overflow menu for rename/archive/delete.
- Channel rows expose visible management affordances or a stable overflow menu for edit/remove/reorder alternatives.
- Hover/context menu/drag affordances may remain as accelerators, but no core workflow depends on them exclusively.
- Keyboard focus order reaches primary and secondary row actions predictably.
- Save-blocking guidance is placed near the Save action and/or required field, with copy that explains exactly what is missing.
- Tests cover visibility/state for the key always-available actions where SwiftUI tests can observe them.

Stopping conditions:

- Stop and ask if destructive actions like delete/archive need confirmation UX not currently specified.
- Stop the slice if adding visible actions causes layout breakage in the fixed popover that cannot be resolved without first changing the popover/navigation layout.
- Do not accept a solution where context menus remain the only route for core actions.

### 4. Visual Design, Accessibility, And macOS Fit

Address:

- Controls are too small and too custom.
- Plain-button styling hides affordances and focus.
- Orange and green carry too much semantic meaning.
- Custom gesture surfaces are not semantically buttons.
- Settings mix custom card/chip surfaces and native grouped forms.
- Full visual redesign is allowed by the user.

Acceptance criteria:

- Core control text uses readable macOS-appropriate sizing; 9-10 pt text is reserved for secondary metadata only.
- Icon controls and row actions have comfortable hit targets, approximately 32 px or larger unless a native control dictates otherwise.
- Custom `.plain` buttons are replaced with native controls where practical or given explicit visual/focus affordances.
- Semantic color roles are separated for brand, primary action, selected state, warning/urgency, success, generated/auto state, and links.
- Color-coded states are paired with non-color indicators such as labels, icons, checks, or shape differences.
- Media/drop-zone and similar custom gesture areas are real buttons or have explicit accessibility labels, hints, and actions.
- Settings surfaces use a consistent visual language after the IA split.
- The final design is checked in the running app at menu bar popover size and at least one larger text/accessibility scenario where feasible.

Stopping conditions:

- Stop and ask the operator if the visual redesign implies new brand assets, icons, or generated imagery.
- Stop the Worker slice if visual changes require replacing the app architecture or moving away from SwiftUI patterns used in the project.
- Do not mark done if the app only looks different but still depends on tiny controls, hover-only actions, or color-only meaning.

### 5. Verification And Final Audit

Acceptance criteria:

- `git diff --check` passes.
- The macOS project builds.
- Relevant automated tests pass locally; if a full test suite is too slow or unavailable, the receipt explains exactly what was run and why.
- Manual walkthrough covers:
  - app visible in the menu bar,
  - zero-state first-run,
  - add channel,
  - create first capture,
  - enable or locate notification setup,
  - inspect planner/posting windows,
  - use queue actions,
  - access true settings,
  - verify no core action is hover/context-only.
- Final audit maps every original critique item to done, intentionally deferred, or blocked with evidence.

Stopping conditions:

- Stop final completion if any required Worker task remains queued or active.
- Stop final completion if verification is red, stale, or not run without a documented reason.
- Stop final completion if the manual walkthrough cannot be performed and no equivalent demo evidence exists.

## Non-Negotiable Constraints

- Preserve existing user changes and do not revert unrelated work.
- Keep edits consistent with SwiftUI and macOS menu bar app conventions unless a task explicitly justifies a broader redesign.
- Do not create implementation changes outside an active Worker or PM task with explicit file scope.
- Prefer the repository's existing patterns and test style.
- Maintain the app's core behavior as a macOS menu bar utility.
- Use automated tests where practical and record manual walkthrough evidence for subjective UX and menu bar behavior.
- If the visual redesign requires assets or branding decisions, ask before creating or importing them.

## Stop Rule

Stop only when a final audit proves the full original outcome is complete.

Do not stop after planning, discovery, or Judge selection if a safe Worker task can be activated.

Do not stop after a single verified Worker package when the broader owner outcome still has safe local follow-up work. Advance the board to the next highest-leverage safe Worker package and continue unless a phase, risk, rejected-verification, ambiguity, or final-completion review is due.

Do not create one Worker/Judge pair per repeated view or helper. Put repeated same-shape UI work into one coherent Worker package and review the package as a whole.

Do not stop because a slice needs owner input, credentials, production access, destructive operations, or policy decisions. Mark that exact slice blocked with a receipt, create the smallest safe follow-up or workaround task, and continue all local, non-destructive work that can still move the goal toward the full outcome.

## Slice Sizing

Safe means bounded, explicit, verified, and reversible. It does not mean tiny.

A good task is the largest safe useful slice.

Worker slices should produce a working UX milestone: first-run route completion, navigation restructuring, action discoverability, visual/accessibility polish, or verification evidence.

## Canonical Board

Machine truth lives at:

`docs/goals/ux-first-run-overhaul/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins for task status, active task, receipts, verification freshness, and completion truth.

## Run Command

```text
/goal Follow docs/goals/ux-first-run-overhaul/goal.md.
```

## PM Loop

On every `/goal` continuation:

1. Read this charter.
2. Read `state.yaml`.
3. Run the bundled GoalBuddy update checker when available and mention a newer version without blocking.
4. Re-check the intake, critique themes, likely misfire, and stopping conditions.
5. Work only on the active board task.
6. Assign Scout, Judge, Worker, or PM according to the task.
7. Write a compact task receipt.
8. Update the board.
9. If safe local work remains, choose the next largest reversible Worker package and continue unless blocked.
10. Review at phase, risk, rejected-verification, ambiguity, or final-completion boundaries.
11. Finish only with a Judge/PM audit receipt that maps receipts and verification back to the original user outcome and records `full_outcome_complete: true`.
