---
name: redditreminder-agent
description: Use when Codex or another agent needs to inspect, test, automate, or modify RedditReminder app data, CLI workflows, release-train behavior, or agent-facing guidance. Triggers include RedditReminder menu bar app tasks, SwiftData store interactions, redditreminder CLI commands, command/recipe discovery, dry-run validation, isolated test stores, and release packaging guardrails.
---

# RedditReminder Agent

## Core Rule

Use the `redditreminder` CLI for agent interaction with the app. The CLI reads and writes the same SwiftData store as the menu bar app and emits stable JSON for agents, scripts, and shell pipelines.

Start from the repository root when available. Prefer repo-local commands before assuming a globally installed CLI exists.

## Bootstrap

Run one of these first:

```sh
./scripts/agent-bootstrap.sh
make agent-bootstrap
redditreminder --json agent bootstrap
```

Use the bootstrap payload to discover command schemas, recipe schemas, current store context, and validation affordances before forming mutations.

## Mutation Safety

For live app data:

1. Prefer recipe flows over raw mutation commands.
2. Validate proposed commands with `agent validate --`.
3. Preview mutations with `agent dry-run --` or `--dry-run` when supported.
4. Ask for confirmation before executing non-dry-run mutations unless the surrounding task explicitly grants mutation authority.
5. Use `--json` for machine-readable output.
6. Use `--store PATH` for isolated tests, experiments, and examples so app data is not changed.

Never write secret values into release records, checklists, logs, or skill/plugin artifacts.

## Common Workflow

```sh
./scripts/agent-bootstrap.sh
build/Build/Products/Debug/redditreminder --json commands list
build/Build/Products/Debug/redditreminder --json recipes list
build/Build/Products/Debug/redditreminder --json agent validate -- projects create "Launch Ideas"
build/Build/Products/Debug/redditreminder --json agent dry-run -- projects create "Launch Ideas"
```

If `build/Build/Products/Debug/redditreminder` is missing, run:

```sh
make build-cli
```

For detailed command examples and release guardrails, read `references/cli-workflows.md`.

## Validation

Use these checks according to the change:

- CLI or agent behavior: `make cli-test`
- Development app build: `make build-dev`
- Development app install validation: `make install-dev`
- Unit tests: `make test`
- Release packaging changes: `make release-dry-run`

Do not run `make release-dmg` unless the operator intentionally provides real signing and notarization credentials for a production release.
