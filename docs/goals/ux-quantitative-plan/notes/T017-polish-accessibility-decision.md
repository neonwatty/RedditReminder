# T017 Judge Decision: macOS Polish and Accessibility Baseline

Decision: select `T006`.

Rationale:
- The highest-leverage remaining non-architecture UX risk is small, icon-heavy controls that either lack deterministic help/identifiers or use sub-28 pt hit frames.
- A bounded slice can improve the popover header/search controls and Posted/Post Handoff icon actions without introducing a visual redesign, new design system, new windows/scenes, or navigation changes.
- These controls are already covered by static presentation tests or can be covered with small deterministic assertions, keeping the work measurable.

Selected Worker task: `T006`.

Allowed files:
- `Sources/Views/PopoverChromeViews.swift`
- `Sources/Views/PostedListView.swift`
- `Sources/Views/PostHandoffViewHelpers.swift`
- `Tests/RedditReminderTests/PopoverChromeViewTests.swift`
- `Tests/RedditReminderTests/PostedListViewTests.swift`
- `Tests/RedditReminderTests/PostHandoffViewTests.swift`

Acceptance criteria:
- Popover header settings/new-capture/search-clear controls expose deterministic labels, help text, identifiers, and a minimum 28x28 pt hit frame.
- Posted list icon-only actions expose deterministic labels/help/identifiers and a minimum 28x28 pt hit frame.
- Post Handoff icon copy buttons expose deterministic labels/help/identifiers and a minimum 28x28 pt hit frame.
- No touched core action label is newly introduced below 11 pt.
- At least three focused tests assert labels, identifiers, and hit-frame constants for touched controls.

Verification:
- `make test`
- `node /Users/neonwatty/.codex/plugins/cache/goalbuddy/goalbuddy/0.3.6/skills/goalbuddy/scripts/check-goal-state.mjs docs/goals/ux-quantitative-plan/state.yaml`

Stop conditions:
- Need files outside the allowed list.
- Work expands into a full visual redesign, new design system, or major navigation restructuring.
- Accessibility changes conflict with existing UI tests without a Judge decision.
- Tests or scripted QA fail twice for the same reason.
