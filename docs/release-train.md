# Release Train

RedditReminder uses a regular production train plus a continuously installable
development app. Production releases are signed and notarized Developer ID DMGs.
Development builds use a separate app identity so maintainers can iterate without
overwriting the production app or production local data.

## App Flavors

| Flavor | Scheme | App name | Bundle ID | Local support directory |
| --- | --- | --- | --- | --- |
| Production | `RedditReminder` | `RedditReminder` | `com.neonwatty.RedditReminder` | `~/Library/Application Support/RedditReminder` |
| Development | `RedditReminderDev` | `RedditReminder Dev` | `com.neonwatty.RedditReminder.Dev` | `~/Library/Application Support/RedditReminder Dev` |

Use the development app for day-to-day iteration:

```sh
make build-dev
make install-dev
make start-dev
make stop-dev
```

Use production builds only for release validation or installing the current
production candidate:

```sh
make build
make install
```

The CLI continues to target the normal app store by default. Use CLI `--store`
for isolated tests and agent experiments.

## Cadence

Default train: review and release from `main` once per week when CI is green and
there are user-facing fixes or features worth shipping. Skip the train if there
is nothing meaningful to publish. Use an out-of-band hotfix only for urgent
production breakage, then let the next normal train continue from `main`.

Use patch releases, such as `0.1.1`, for production regressions, packaging or
release-process fixes, documentation corrections, and low-risk polish. Use a
minor release, such as `0.2.0`, when the train includes meaningful feature
scope or user-facing workflow changes. Do not publish a patch release just to
keep the calendar moving.

Track each train with a GitHub milestone and one tracking issue. The active
post-`0.1.0` patch train is
[v0.1.1](https://github.com/neonwatty/RedditReminder/milestone/1), tracked by
[issue #137](https://github.com/neonwatty/RedditReminder/issues/137), with a
target train date of July 10, 2026.

Recommended pre-train checks:

```sh
make build-dev
make test
make cli-test
make release-dry-run
```

Run `make ui-test` when the local macOS automation environment is healthy.

## Local Production Packaging

Dry-run the release command without credentials or external side effects:

```sh
make release-dry-run
```

Create a signed, notarized DMG locally when the Developer ID certificate is
installed in the keychain and App Store Connect notarization credentials are
available:

```sh
APPLE_TEAM_ID=... \
APP_STORE_CONNECT_KEY_ID=... \
APP_STORE_CONNECT_ISSUER_ID=... \
APP_STORE_CONNECT_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)" \
make release-dmg VERSION=0.1.0 BUILD=1
```

Optional:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example, LLC (TEAMID)"
RELEASE_OUTPUT_DIR=build/release
DERIVED_DATA_PATH=build/release/DerivedData
```

The release command archives the production scheme, exports the app, verifies
the code signature and bundle version, creates and signs a DMG, submits it to
notarytool, staples and validates the DMG, runs Gatekeeper validation, and writes
a `.sha256` checksum.

## GitHub Release Automation

Releases are staged manually from the `Staged Release` GitHub Actions workflow.
The operator chooses the release version, source ref, draft/prerelease state,
and optionally a build number. The workflow defaults to a draft GitHub Release
so the signed and notarized artifact can be smoke-tested before publication.

The staged workflow:

1. Checks out the requested branch, tag, or SHA.
2. Verifies signing and notarization secrets with
   `scripts/prepare-release-signing.sh`.
3. Runs `make build-dev`, `make test`, `make cli-test`, and
   `make release-dry-run`.
4. Runs `make release-dmg VERSION=<version> BUILD=<build>`.
5. Uploads the DMG and checksum as workflow artifacts for review.
6. Creates or updates draft release `v<version>` with the signed/notarized DMG
   and `.sha256` checksum.

To stage a release from GitHub:

1. Open **Actions > Staged Release > Run workflow**.
2. Enter the version without a leading `v`, for example `0.1.0`.
3. Use `main` or a specific tag/SHA for `ref`.
4. Leave `draft` enabled for normal release candidates.
5. Run the workflow, download the artifacts, perform smoke checks, then publish
   the draft release when ready.

Copy [release-checklist.md](release-checklist.md) to
`docs/releases/v<version>.md` for each train, then record the workflow run URL,
artifact URLs, smoke-test evidence, and publish/fix decision there. Never write
secret values into the checklist or release record.

Required GitHub Actions secrets:

| Secret | Purpose |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID used for Developer ID signing and export. |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID for notarization. |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID for notarization. |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of the `.p8` App Store Connect API private key. |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64` | Base64-encoded `.p12` Developer ID Application certificate. |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD` | Password for the `.p12` certificate. |
| `KEYCHAIN_PASSWORD` | Temporary CI keychain password. |

Optional:

| Secret | Purpose |
| --- | --- |
| `DEVELOPER_ID_APPLICATION` | Full signing identity name. Defaults to `Developer ID Application`. |

Create the certificate secret from a local `.p12` with:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## Release Smoke Checks

After a GitHub Release is published:

```sh
shasum -a 256 -c RedditReminder-*-macos.dmg.sha256
spctl -a -vv -t open --context context:primary-signature RedditReminder-*-macos.dmg
xcrun stapler validate RedditReminder-*-macos.dmg
```

Mount the DMG, copy `RedditReminder.app` to `/Applications`, launch it, and
verify the menu bar item opens. Confirm `RedditReminder Dev.app` can still be
installed and launched separately.

## Rollback

Prefer fix-forward releases for normal regressions so version history stays
monotonic. For a bad GitHub Release asset, mark the release as a draft or delete
the release asset, communicate the withdrawn version, and ship a new patch
release from `main`. Do not reuse a published semantic version.

## Deferred Distribution

Homebrew cask automation is intentionally deferred. The first release-train
tranche publishes signed and notarized GitHub Release assets; a cask can be added
after at least one production DMG has been published and smoke-tested.
