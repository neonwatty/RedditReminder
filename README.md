# RedditReminder

[![Discord](https://img.shields.io/badge/Discord-Join%20Server-7289da?style=flat&logo=discord&logoColor=white)](https://discord.gg/7xsxU4ZG6A)

macOS menu bar app for preparing Reddit posts, tracking subreddit posting windows, and getting nudged when it is time to post.

## Workflow

1. Add the subreddits you post to in **Settings > Channels**.
2. Optionally add each subreddit's posting checklist, such as flair reminders, weekly-thread rules, or promo limits.
3. Create captures from the menu bar popover with a title, body, links, media, notes, project, and target subreddit.
4. Use **Prepare Post** from a queue card to open the handoff window.
5. Copy title/body/links/full text, open Reddit, attach media manually if needed, then mark the capture posted.
6. Use **Settings > Planner** to scan the next 7 days of posting windows and queue readiness.

## Main Features

- Menu bar queue for Reddit post drafts.
- Capture editor with title, markdown body preview, links, media, notes, project, and subreddit selection.
- Per-subreddit peak posting windows generated from bundled heuristics or user overrides.
- 7-day planner grouped by day with readiness counts.
- Posting handoff window with copy actions, checklist notes, media/link summary, and Reddit submit-page launch.
- Posted history with optional saved Reddit post URLs.
- macOS notifications for upcoming posting windows and empty-queue nudges.
- Backup/export and import for captures, projects, subreddits, settings, media payloads, and checklists.

## Shortcuts

- `Cmd+Shift+R`: Toggle the menu bar popover.
- `Cmd+N`: New capture.
- `Cmd+,`: Preferences.

The global shortcut requires macOS Accessibility permission for the terminal/app build that registers it.

## Development

```sh
make generate
make test
make ui-test
make build-debug
make install-debug
make build-dev
make install-dev
```

Local smoke QA:

```sh
make qa
```

The QA script uses System Events and CGWindowList, so the terminal needs Accessibility and Screen Recording permissions.
The UI test target exercises native menu/window smoke coverage. It requires macOS UI automation permission for Xcode or the invoking terminal, and a signing setup that can run XCTest UI bundles.
UI tests launch RedditReminder with a per-test `--ui-test-store` path so `--seed-qa` and `--clear-qa` operate on isolated SwiftData storage instead of the normal app store.
CI runs unit, CLI, and UI test jobs for code changes. Package and release metadata
changes run a lightweight npm metadata validation job. Coverage is reported and
uploaded by CI, but it is not enforced as a numeric gate yet.

### Release Train

Use `RedditReminder Dev` for continuous local iteration and reserve
`RedditReminder` for production candidates and published releases. The dev app
has a separate bundle ID and Application Support directory, so it can coexist
with the production app.

```sh
make release-dry-run
```

Production DMGs are built by `make release-dmg VERSION=... BUILD=...` and by the
manual **Staged Release** GitHub Actions workflow when signing/notarization
secrets are configured. See [docs/release-train.md](docs/release-train.md) for
the full runbook, required secrets, smoke checks, and rollback guidance. Use
[docs/release-checklist.md](docs/release-checklist.md) to record each staged
release rehearsal.

## Notes

RedditReminder intentionally does not mirror Reddit's full composer schema. Flair, media rules, and post types vary by subreddit, so the app stores durable prep data and checklist reminders, then hands off to Reddit for the final subreddit-specific posting step.
