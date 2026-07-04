# T002 Judge Decision

## Decision

Start with Slice A: add a compact Settings/Preferences footer that displays app version and build from bundle metadata.

## Rationale

- The user's immediate app concern is that the version number is not visible.
- `PreferencesView` is the lowest-risk global surface because it already owns the Settings window frame and tabs.
- The footer can be derived from `CFBundleShortVersionString`, `CFBundleVersion`, and bundle display/name values, avoiding hard-coded release values.
- This slice has focused unit-test coverage and a clear build verification path.

## Agent Artifact Decision

Use a skill-only artifact for this tranche. Defer plugin packaging.

Rationale:

- Repo-local `AGENTS.md` already covers agents inside this checkout.
- A skill adds distribution value by teaching agents how to use RedditReminder from outside this repo context.
- Plugin wrapping is useful for marketplace/installable packaging, but it is not required to satisfy the current outcome and would add packaging overhead before the skill itself is proven useful.

## T003 Worker Scope

Allowed files:

- `Sources/Views/PreferencesView.swift`
- `Sources/Utilities/AppVersionInfo.swift`
- `Tests/RedditReminderTests/AppVersionInfoTests.swift`
- `Tests/RedditReminderTests/PreferencesViewTests.swift`

Verify:

- `git diff --check`
- `make build-dev`
- focused unit tests for `AppVersionInfoTests` and `PreferencesViewTests` where the local Xcode test filter is reliable

Stop if:

- Version/build display would require hard-coded release values.
- The Settings layout needs a broader redesign outside `PreferencesView`.
- Focused tests fail twice for the same implementation reason.

## T004 Worker Scope

Allowed files:

- `skills/redditreminder-agent/SKILL.md`
- `skills/redditreminder-agent/agents/openai.yaml`
- `skills/redditreminder-agent/references/cli-workflows.md`
- `AGENTS.md`
- `docs/agent-distribution.md`

Verify:

- `git diff --check`
- `python3 /Users/neonwatty/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/redditreminder-agent`
- `./scripts/agent-bootstrap.sh`
- `make cli-test` if the skill changes alter agent command assumptions

Stop if:

- The skill duplicates `AGENTS.md` without adding distribution value.
- The artifact location proves incompatible with skill validation.
- Plugin packaging becomes necessary before the skill content is validated.
