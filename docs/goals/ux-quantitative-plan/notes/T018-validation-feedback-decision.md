# T018 Judge Decision: Validation Feedback Slice

Decision: select `T007`.

Rationale:
- `CaptureLinksSection.addLink()` silently returns when `CaptureHelpers.normalizeLink(_:)` rejects input, leaving users without recovery feedback.
- `CaptureMediaSection` already has a visible rejected-file message, but importer and drop-provider failures only log to Console.
- A safe slice can add inline messages and stable accessibility identifiers without persistence, model, network, or architecture changes.

Selected Worker task: `T007`.

Allowed files:
- `Sources/Utilities/CaptureHelpers.swift`
- `Sources/Utilities/CaptureMediaAccessibility.swift`
- `Sources/Views/CaptureLinksSection.swift`
- `Sources/Views/CaptureMediaSection.swift`
- `Tests/RedditReminderTests/CaptureHelpersTests.swift`
- `Tests/RedditReminderTests/CaptureMediaAccessibilityTests.swift`

Acceptance criteria:
- Invalid non-empty link entry produces visible inline feedback with a deterministic accessibility identifier and does not clear the user's input.
- Valid link entry still appends the normalized URL, clears the input, and clears any prior validation message.
- Empty link entry remains a no-op without showing an error.
- Media importer failure and file-drop provider failure set visible inline feedback instead of logging only.
- Media rejected-file feedback uses a shared static message and accessibility identifier.
- At least two focused tests cover invalid link messaging and media failure/rejection messaging.

Verification:
- `make test`
- `node /Users/neonwatty/.codex/plugins/cache/goalbuddy/goalbuddy/0.3.6/skills/goalbuddy/scripts/check-goal-state.mjs docs/goals/ux-quantitative-plan/state.yaml`

Stop conditions:
- Need files outside the allowed list.
- Validation changes require broad model, persistence, or network-dependent behavior.
- Tests or scripted QA fail twice for the same reason.
