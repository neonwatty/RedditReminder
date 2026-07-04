# RedditReminder CLI Workflows

## Discovery

Use discovery before guessing syntax:

```sh
./scripts/agent-bootstrap.sh
build/Build/Products/Debug/redditreminder --json commands list
build/Build/Products/Debug/redditreminder --json commands show captures.create
build/Build/Products/Debug/redditreminder --json recipes list
build/Build/Products/Debug/redditreminder --json recipes search --query dry-run
build/Build/Products/Debug/redditreminder --json recipes show posting.create-with-media-dry-run
```

`agent bootstrap` includes command and recipe schemas directly, so it is usually enough for forming valid CLI calls.

## Search and Context

```sh
build/Build/Products/Debug/redditreminder --json context show --limit 10
build/Build/Products/Debug/redditreminder --json search all --query "launch"
```

## Safe Mutations

Validate first:

```sh
build/Build/Products/Debug/redditreminder --json agent validate -- projects create "Launch Ideas"
```

Preview next:

```sh
build/Build/Products/Debug/redditreminder --json agent dry-run -- projects create "Launch Ideas"
build/Build/Products/Debug/redditreminder --json --dry-run projects create "Launch Ideas"
```

Execute only after approval when working against live app data, unless the operator has explicitly granted mutation authority.

## Isolated Test Stores

Use a temporary store for examples, tests, or exploratory mutations:

```sh
STORE="$(mktemp -d)/redditreminder.store"
build/Build/Products/Debug/redditreminder --json --store "$STORE" projects create "Launch Ideas"
build/Build/Products/Debug/redditreminder --json --store "$STORE" context show --limit 10
```

## Common Commands

```sh
build/Build/Products/Debug/redditreminder --json projects create "Launch Ideas"
build/Build/Products/Debug/redditreminder --json captures create --title "Launch" --subreddit SideProject
build/Build/Products/Debug/redditreminder --json subreddits add --verify SideProject
build/Build/Products/Debug/redditreminder --json peaks set SideProject --days mon,wed --hours 9,10
```

Prefer recipe flows when a recipe covers the workflow.

## Release Train Guardrails

Use development app validation for normal iteration:

```sh
make build-dev
make install-dev
```

Use release dry runs before changing packaging or CI release behavior:

```sh
make release-dry-run
```

Do not run production release packaging unless signing and notarization credentials are intentionally available:

```sh
make release-dmg VERSION=0.1.0 BUILD=1
```

Use `docs/release-checklist.md` to record workflow URLs, artifact URLs, smoke-test results, and publish/fix decisions. Never write secret values into the checklist.
