# Staged Release Checklist

Use this checklist for each RedditReminder production release train. Keep one
copy per release issue, PR, or draft-release note. Do not paste certificates,
API keys, private keys, passwords, or notarization credentials into this file or
any public issue.

## Release Inputs

- Version: 0.1.0
- Build number: 4
- Source ref: main (`50e34d7fc7aeac46b698deda6a820ce8d7a494c0`)
- Draft release: yes
- Prerelease: no
- Operator: Codex
- Date: 2026-07-03
- Published release: yes, 2026-07-03T20:55:14Z

## Preflight

- [x] CI is green for the source ref.
- [x] `RedditReminder Dev` build remains healthy.
- [x] No required release-train changes are still unmerged.
- [x] Required GitHub Actions secrets are configured by name:
  - [x] `APPLE_TEAM_ID`
  - [x] `APP_STORE_CONNECT_KEY_ID`
  - [x] `APP_STORE_CONNECT_ISSUER_ID`
  - [x] `APP_STORE_CONNECT_PRIVATE_KEY`
  - [x] `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`
  - [x] `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`
  - [x] `KEYCHAIN_PASSWORD`
- [ ] Optional signing identity secret is configured if the default identity is
      not sufficient:
  - [ ] `DEVELOPER_ID_APPLICATION`

## Workflow Run

- Workflow: **Actions > Staged Release > Run workflow**
- Workflow run URL: https://github.com/neonwatty/RedditReminder/actions/runs/28678939865
- GitHub draft release URL: https://github.com/neonwatty/RedditReminder/releases/tag/untagged-cc1a8ebb5719d8b0029c
- Published release URL: https://github.com/neonwatty/RedditReminder/releases/tag/v0.1.0
- Artifact URL: https://github.com/neonwatty/RedditReminder/releases/download/v0.1.0/RedditReminder-0.1.0-macos.dmg
- Checksum URL: https://github.com/neonwatty/RedditReminder/releases/download/v0.1.0/RedditReminder-0.1.0-macos.dmg.sha256
- DMG filename: `RedditReminder-0.1.0-macos.dmg`
- Checksum filename: `RedditReminder-0.1.0-macos.dmg.sha256`
- DMG SHA256: `d5db1b947d04d2b296842e78a331db8b4d78dc95f141b99dac47099e89e4c585`

Expected workflow checks:

- [x] `scripts/prepare-release-signing.sh`
- [x] `make build-dev`
- [x] `make test`
- [x] `make cli-test`
- [x] `make release-dry-run`
- [x] `make release-dmg VERSION=<version> BUILD=<build>`
- [x] Upload release artifacts for review
- [x] Create or update staged GitHub Release

## Artifact Smoke Checks

Download the DMG and checksum from the draft release or workflow artifact, then
run:

```sh
shasum -a 256 -c RedditReminder-*-macos.dmg.sha256
spctl -a -vv -t open --context context:primary-signature RedditReminder-*-macos.dmg
xcrun stapler validate RedditReminder-*-macos.dmg
```

Record results:

- [x] Checksum passed.
- [x] Gatekeeper validation passed.
- [x] Stapler validation passed.
- [x] DMG mounts.
- [x] `RedditReminder.app` copies to `/Applications`.
- [x] `RedditReminder.app` launches.
- [ ] Menu bar item appears.
- [ ] Popover opens.
- [ ] Settings open.
- [x] Existing production data is readable.
- [x] `RedditReminder Dev.app` installs and launches separately.
- [x] Development data remains separate from production data.

Smoke notes:

```text
Published release assets were downloaded to /tmp/redditreminder-0.1.0-published.
`shasum -a 256 -c RedditReminder-0.1.0-macos.dmg.sha256` returned OK.
`spctl -a -vv -t open --context context:primary-signature` accepted the DMG
as Notarized Developer ID from Developer ID Application: Mean Weasel LLC
(B3A6AN2HA4). `xcrun stapler validate` returned "The validate action worked!".
The public DMG mounted successfully, and the app inside verified with
`codesign --verify --deep --strict` and `spctl -a -vv -t exec`.

`/Applications/RedditReminder.app` is installed as bundle
`com.neonwatty.RedditReminder`, version 0.1.0, build 4. Production app launch
was confirmed by process inspection. Production data readability was confirmed
with `build/Build/Products/Debug/redditreminder --json context show --limit 5`.
`~/Applications/RedditReminder Dev.app` is installed and running separately as
bundle `com.neonwatty.RedditReminder.Dev`; production and development app
support directories are separate.

Menu bar item, popover, and settings checks still need a human visual pass.
```

## Decision

Choose one:

- [x] Publish draft release.
- [ ] Keep draft and fix release workflow or packaging.
- [ ] Delete/replace draft artifact before publication.
- [ ] Cut a new patch version.
- [ ] Blocked by external Apple/GitHub setup.

Decision rationale:

```text
Published v0.1.0 after the staged workflow completed successfully on main at
50e34d7fc7aeac46b698deda6a820ce8d7a494c0, the draft release metadata pointed
at the same commit, and public release assets passed checksum, Gatekeeper,
stapler, DMG mount, bundle signature, install, launch, and production data
readability checks.
```

Follow-up issue or PR:

- Record release checklist PR: https://github.com/neonwatty/RedditReminder/pull/134
