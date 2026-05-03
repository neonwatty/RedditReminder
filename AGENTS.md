# RedditReminder Agent Guide

Use the `redditreminder` CLI for all agent interaction with the menu bar app.
The CLI reads and writes the same SwiftData store as the app and emits stable
JSON for Codex, Claude Code, scripts, and shell pipelines.

## Start Here

```sh
./scripts/agent-bootstrap.sh
```

That source-tree entry point builds the CLI if needed, then runs:

```sh
build/Build/Products/Debug/redditreminder --json agent bootstrap
```

The Makefile target is equivalent:

```sh
make agent-bootstrap
```

If `redditreminder` is already on `PATH`, this also works:

```sh
redditreminder --json agent bootstrap
```

To install the CLI globally:

```sh
make install-cli
~/bin/redditreminder --json agent bootstrap
```

For local repo testing without installing:

```sh
make build-cli
build/Build/Products/Debug/redditreminder --json agent bootstrap
```

## Agent Rules

- Prefer `agent bootstrap`, `commands list`, and `recipes list` before guessing
  syntax.
- Prefer recipe flows over raw mutation commands.
- Validate proposed commands with `agent validate --` before execution.
- Preview mutations with `agent dry-run --`, then ask for confirmation.
- Use `--json` for machine-readable output.
- Use `--dry-run` before mutations when supported.
- Ask for user confirmation before executing non-dry-run mutations.
- Use `--store PATH` for isolated tests so app data is not changed.

## Discovery Flow

```sh
redditreminder --json context show --limit 10
redditreminder --json agent validate -- projects create "Launch Ideas"
redditreminder --json agent dry-run -- projects create "Launch Ideas"
redditreminder --json commands list
redditreminder --json commands show captures.create
redditreminder --json recipes list
redditreminder --json recipes search --query dry-run
redditreminder --json recipes show posting.create-with-media-dry-run
```

`agent bootstrap` includes command schemas and recipe schemas directly, so an
agent can usually form valid commands from that single response. Use
`commands show ID` or `recipes show ID` when a focused schema is easier to work
with than the full bootstrap payload.

## Common Workflows

- Search workspace state: `redditreminder --json search all --query "launch"`
- Create a project: `redditreminder --json projects create "Launch Ideas"`
- Add a subreddit safely: `redditreminder --json subreddits add --verify SideProject`
- Configure peaks: `redditreminder --json peaks set SideProject --days mon,wed --hours 9,10`
- Preview a mutation: `redditreminder --json --dry-run projects create "Draft"`

## Verification

Run agent-focused CLI checks with:

```sh
make cli-test
```
