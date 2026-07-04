# T001 Scout Map: Version Surface and Agent Distribution

## Current Version/Build Flow

- `project.yml` defines base build settings:
  - `MARKETING_VERSION: "0.1.0"`
  - `CURRENT_PROJECT_VERSION: "1"`
- Both app targets map those build settings into bundle metadata:
  - `CFBundleShortVersionString: "$(MARKETING_VERSION)"`
  - `CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"`
- `Sources/Info.plist` also contains the same placeholders:
  - `CFBundleShortVersionString` = `$(MARKETING_VERSION)`
  - `CFBundleVersion` = `$(CURRENT_PROJECT_VERSION)`
- Release packaging overrides the build through `make release-dmg VERSION=<version> BUILD=<build>`.
  The published `v0.1.0` record confirms production was version `0.1.0`, build `4`.
- Scout found no app UI code that renders `CFBundleShortVersionString` or `CFBundleVersion`.

## Current Settings/Preferences Surface

- `Sources/Views/PreferencesView.swift` owns the Settings window content.
- It lays out:
  - tab strip in a top `HStack`
  - `Divider()`
  - selected tab content (`GeneralTabView`, `NotificationsTabView`, or `BackupTabView`)
- `Sources/Views/GeneralTabView.swift` currently renders a grouped `Form` with:
  - Keyboard Shortcut
  - Defaults
  - Menu Bar
- `Tests/RedditReminderTests/PreferencesViewTests.swift` already verifies tab shape and default tab.
- `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift` verifies Preferences tab navigation through `preferences.tab.*` and `preferences.content.*` identifiers.

## UI Recommendation

Use a compact Settings/Preferences footer, not the main popover footer.

Rationale:

- Version/build metadata is support/debug metadata, not part of the posting workflow.
- The popover is a high-frequency workspace surface with queue, planner, channels, and post actions.
- `PreferencesView` already has a stable vertical container and can display a global app footer below any selected tab.
- The footer can read bundle metadata at runtime and stay valid for dev, debug, and release builds.

Suggested implementation shape:

- Add a small helper for bundle display metadata, for example:
  - `Sources/Utilities/AppVersionInfo.swift`
  - reads `CFBundleShortVersionString`, `CFBundleVersion`, `CFBundleDisplayName` or `CFBundleName`
  - exposes display text such as `RedditReminder 0.1.0 (4)` or `Version 0.1.0 · Build 4`
- Add a footer in `PreferencesView` below the selected tab content:
  - small secondary text
  - accessibility identifier such as `preferences.footer.version`
  - should work for production and development bundle names
- Add unit tests for the formatter/helper and, if practical, a simple Preferences constant/identifier test.
- Optionally extend UI tests later to assert `preferences.footer.version`, but local UI automation has been brittle in this repo; unit coverage plus build may be sufficient for the first slice.

## Agent-Facing Distribution Map

Current repo-local agent guidance:

- `AGENTS.md` already tells agents to use the `redditreminder` CLI for all app interaction.
- It includes:
  - bootstrap commands
  - discovery flow
  - validation/dry-run rules
  - `--json`
  - `--store PATH` for isolated tests
  - release train constraints and no-secret checklist reminder

CLI support is strong:

- `./scripts/agent-bootstrap.sh` builds the CLI if needed and runs `redditreminder --json agent bootstrap`.
- `make cli-test` runs:
  - `scripts/cli-smoke.sh`
  - `scripts/cli-agent-smoke.sh`
  - `scripts/cli-catalog-check.py`
- `agent bootstrap` returns versioned schemas and recipes, including `agent.validate`, `agent.dry-run`, `commands.list`, and `recipes.list`.

## Skill vs Plugin Options

### AGENTS.md only

Good for this repo, but not enough for broader distribution. It does not help an agent outside this checkout discover RedditReminder-specific behavior unless the repo is already loaded.

### Skill-only artifact

Best first distribution artifact for this goal.

Recommended content:

- Trigger when the user asks an agent to inspect, modify, test, or automate RedditReminder app data.
- Tell the agent to prefer:
  - `./scripts/agent-bootstrap.sh`
  - `redditreminder --json agent bootstrap`
  - `commands list/show`
  - `recipes list/show/search`
  - `agent validate --`
  - `agent dry-run --`
  - `--store PATH` for isolated tests
- Preserve important rules:
  - use `--json`
  - prefer recipes over raw mutation commands
  - ask before non-dry-run mutations
  - do not write secrets into release records
  - use `make build-dev` / `make install-dev` for dev validation
  - do not run `make release-dmg` unless real signing/notarization credentials are intentionally provided
- Keep the skill lean; move command examples into one reference file only if the `SKILL.md` gets too long.

Validation:

- Use skill-creator requirements.
- Ensure `SKILL.md` has valid frontmatter (`name`, `description`) and concise body.
- Generate `agents/openai.yaml` if creating a polished skill.
- Run:
  - `python3 /Users/neonwatty/.codex/skills/.system/skill-creator/scripts/quick_validate.py <skill-dir>`

### Plugin-wrapped skill

Useful later if the team wants marketplace/UI install/share, bundled scripts, or MCP/app packaging.

Not required for the first slice unless Judge decides distribution beyond repo-local files is part of this tranche. Plugin creation should follow plugin-creator:

- scaffold with `scripts/create_basic_plugin.py`
- include `.codex-plugin/plugin.json`
- optionally include a `skills/` folder
- validate with:
  - `python3 /Users/neonwatty/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py <plugin-path>`

## Candidate Worker Slices

### Slice A: Settings version/build footer

Allowed files:

- `Sources/Views/PreferencesView.swift`
- `Sources/Utilities/AppVersionInfo.swift` (new)
- `Tests/RedditReminderTests/AppVersionInfoTests.swift` (new)
- possibly `Tests/RedditReminderTests/PreferencesViewTests.swift`

Verification:

- `git diff --check`
- `make build-dev`
- focused unit tests if the Swift Testing filter is reliable, otherwise `make test`
- optional installed dev app inspection:
  - `make install-dev`
  - inspect `~/Applications/RedditReminder Dev.app/Contents/Info.plist`

Stop if:

- UI would need a hard-coded version/build.
- Preferences layout becomes unstable or crowded.
- Tests cannot prove the formatter reads bundle-like metadata.

### Slice B: Agent skill artifact and docs

Allowed files depend on final location. Candidate repo-local paths:

- `skills/redditreminder-agent/SKILL.md`
- `skills/redditreminder-agent/agents/openai.yaml`
- optional `skills/redditreminder-agent/references/cli-workflows.md`
- `docs/agent-distribution.md` or `docs/release-train.md` if a distribution note is needed
- `AGENTS.md` only if the existing repo-local guidance needs a pointer to the skill

Verification:

- `git diff --check`
- `python3 /Users/neonwatty/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/redditreminder-agent`
- `./scripts/agent-bootstrap.sh`
- `make cli-test` if the skill/docs change touches agent command assumptions

Stop if:

- The skill duplicates `AGENTS.md` without adding distribution value.
- The artifact location is ambiguous.
- Plugin packaging is chosen but plugin-creator instructions have not been loaded by Worker.

### Slice C: Plugin wrapper, if explicitly selected

Allowed files depend on chosen plugin location. Candidate repo-local path:

- `plugins/redditreminder-agent/.codex-plugin/plugin.json`
- `plugins/redditreminder-agent/skills/redditreminder-agent/SKILL.md`
- optional repo marketplace file only if intentionally creating repo/team marketplace distribution

Verification:

- `git diff --check`
- `python3 /Users/neonwatty/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/redditreminder-agent`
- skill validation for nested skill

Stop if:

- A personal marketplace write outside the repo would be required unexpectedly.
- The user has not asked for installable marketplace packaging.

## Recommended Next Judge Decision

Choose Slice A first, because it directly answers the user's visible version concern and has a tight, low-risk verification path. Choose Slice B second as a skill-only artifact unless the user explicitly needs marketplace/plugin installability now. Defer plugin wrapper to a follow-up unless skill distribution proves insufficient.
