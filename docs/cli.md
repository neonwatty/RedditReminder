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

## Agent Discovery

```sh
redditreminder context show --json
redditreminder context show --limit 5 --json
redditreminder search all --query "launch" --json
redditreminder search all --query "weekday" --limit 10 --json
redditreminder commands list --json
redditreminder commands show captures.create --json
redditreminder recipes list --json
redditreminder recipes search --query "media" --json
redditreminder recipes show posting.create-with-media --json
```

`context show` returns a compact snapshot of the workspace: counts, projects,
subreddits with peak summaries, queued captures, active events, and peak presets.
`search all` searches captures, events, projects, subreddits, and peak presets so
agents can inspect the widget state without guessing which domain to query first.
`commands list` and `commands show` return structured command metadata for agents:
schema versions, command ids, positionals, flags, examples, and output data shapes.
`recipes list`, `recipes search`, and `recipes show` return higher-level agent
workflows: schema versions, expected inputs, ordered command steps, example
invocations, and related command ids.

## Captures

```sh
redditreminder captures list --json
redditreminder captures search --query "launch" --json
redditreminder captures create --title "Launch post" --text "Post body" --project "Launch Ideas" --subreddit SideProject --media ~/Desktop/mock.png --due 2026-05-02T18:00:00Z --json
redditreminder captures update CAPTURE_ID --title "Updated title" --clear-notes --json
redditreminder captures mark-posted CAPTURE_ID --url "https://reddit.com/r/SideProject/comments/abc" --json
redditreminder captures mark-queued CAPTURE_ID --json
redditreminder captures delete CAPTURE_ID --json
```

`captures create` accepts:

```sh
--title TEXT          Optional post title.
--text TEXT           Post body. If omitted, trailing arguments become the body.
--notes TEXT          Private notes.
--link URL            Repeatable link value.
--links A,B           Comma-separated links.
--project NAME_OR_ID  Existing project name or UUID.
--subreddit NAME      Repeatable existing subreddit name or UUID.
--subreddits A,B      Comma-separated subreddits.
--media PATH          Repeatable image path copied into the media store.
--media-paths A,B     Comma-separated image paths.
--due ISO8601         Creates one one-off posting-window event per chosen subreddit.
```

`captures update` accepts the same editable fields plus lifecycle-safe clearing flags:

```sh
--clear-title
--clear-notes
--clear-links
--clear-project
--clear-subreddits
--remove-media REF       Repeatable stored media ref to remove.
--remove-media-refs A,B  Comma-separated stored media refs.
--clear-media
```

There is no separate due-date field on captures today. `--due` maps to the app's
posting-window model by creating `SubredditEvent` rows for the selected subreddit(s).

## Events

```sh
redditreminder events list --json
redditreminder events search --query "launch" --json
redditreminder events list --subreddit SideProject --manual --active --from 2026-05-02T00:00:00Z --to 2026-05-03T00:00:00Z --json
redditreminder events create --subreddit SideProject --name "Launch window" --date 2026-05-02T18:00:00Z --lead-minutes 30 --json
redditreminder events update EVENT_ID --name "Updated window" --date 2026-05-02T19:00:00Z --lead-minutes 45 --json
redditreminder events update EVENT_ID --deactivate --json
redditreminder events update EVENT_ID --activate --json
redditreminder events delete EVENT_ID --json
```

Generated peak-time events are read-only through `events update/delete`. Change
those through `peaks set` or `peaks reset` so generated windows stay in sync with
the subreddit peak-time configuration.

## Projects

```sh
redditreminder projects list --json
redditreminder projects search --query "launch" --json
redditreminder projects create "Launch Ideas" --json
redditreminder projects update "Launch Ideas" --name "Launch Plan" --description "Release checklist" --color "#FF4500" --json
redditreminder projects update "Launch Plan" --archive --json
redditreminder projects update "Launch Plan" --unarchive --clear-description --clear-color --json
redditreminder projects delete "Launch Plan" --json
redditreminder --dry-run projects create "Launch Ideas" --json
```

Project delete uses the app's current model behavior and cascades captures assigned
to that project.

## Subreddits

```sh
redditreminder subreddits list --json
redditreminder subreddits search --query "swift" --json
redditreminder subreddits verify SideProject --json
redditreminder subreddits add SideProject --json
redditreminder subreddits add --verify SideProject --json
redditreminder subreddits update SideProject --name SideProjects --checklist "Read rules before posting" --json
redditreminder subreddits update SideProjects --clear-checklist --json
redditreminder subreddits delete SideProjects --json
redditreminder subreddits add https://www.reddit.com/r/SwiftUI/comments/abc --json
```

Subreddit names are normalized the same way as the app UI. Duplicate names are
rejected case-insensitively. `subreddits verify` checks Reddit before saving
anything. `subreddits add --verify` performs that same check and only saves the
subreddit when Reddit returns a valid `/about.json` response.

Subreddit delete cascades subreddit events and cancels their pending notifications,
but it does not delete captures.

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
