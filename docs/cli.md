# RedditReminder CLI

`redditreminder` is the agent-friendly command-line interface for the menu bar app.
It reads and writes the same SwiftData store as the app and supports JSON output for
Codex, Claude Code, scripts, and shell pipelines.

## Install

```sh
make install-cli
```

This installs:

```txt
~/bin/redditreminder
~/bin/RedditReminderResources/peak-times.json
```

## Global Flags

```sh
--json          Emit a stable JSON response envelope.
--pretty        Pretty-print JSON. Implies --json.
--dry-run       Report the mutation that would happen without saving.
--store PATH    Use a specific SwiftData store. Useful for tests.
```

JSON responses use this envelope:

```json
{
  "ok": true,
  "data": {},
  "warnings": [],
  "errors": []
}
```

## Captures

```sh
redditreminder captures list --json
redditreminder captures search --query "launch" --json
```

This first CLI slice is read-only for captures. Capture creation and media attachment
are planned next.

## Projects

```sh
redditreminder projects list --json
redditreminder projects search --query "launch" --json
redditreminder projects create "Launch Ideas" --json
redditreminder --dry-run projects create "Launch Ideas" --json
```

## Subreddits

```sh
redditreminder subreddits list --json
redditreminder subreddits search --query "swift" --json
redditreminder subreddits add SideProject --json
redditreminder subreddits add https://www.reddit.com/r/SwiftUI/comments/abc --json
```

Subreddit names are normalized the same way as the app UI. Duplicate names are
rejected case-insensitively.

## Peak Times

```sh
redditreminder peaks presets --json
redditreminder peaks get SideProject --json
redditreminder peaks set SideProject --days mon,wed,fri --hours 9,10,11 --json
redditreminder peaks set SideProject --days sat,sun --hours 10,11 --timezone America/Phoenix --json
redditreminder peaks reset SideProject --json
```

`peaks set` accepts local hours and stores UTC overrides, matching the app's peak
time model. Generated posting-window events are resynced after set/reset.

## Isolated Store Example

Use `--store` to test commands without touching app data:

```sh
STORE="$(mktemp -d)/redditreminder.store"
redditreminder --store "$STORE" --json projects create "Test Project"
redditreminder --store "$STORE" --json subreddits add SideProject
redditreminder --store "$STORE" --json peaks set SideProject --days mon --hours 9
```
