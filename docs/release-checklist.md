# Staged Release Checklist

Use this checklist for each RedditReminder production release train. Copy it to
`docs/releases/v<version>.md` or to the release issue before filling it in. Do
not paste certificates, API keys, private keys, passwords, or notarization
credentials into this file or any public issue.

## Release Inputs

- Version:
- Build number:
- Source ref:
- Draft release: yes
- Prerelease: no
- Operator:
- Date:
- Published release:

## Preflight

- [ ] CI is green for the source ref.
- [ ] `RedditReminder Dev` build remains healthy.
- [ ] No required release-train changes are still unmerged.
- [ ] Required GitHub Actions secrets are configured by name:
  - [ ] `APPLE_TEAM_ID`
  - [ ] `APP_STORE_CONNECT_KEY_ID`
  - [ ] `APP_STORE_CONNECT_ISSUER_ID`
  - [ ] `APP_STORE_CONNECT_PRIVATE_KEY`
  - [ ] `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`
  - [ ] `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`
  - [ ] `KEYCHAIN_PASSWORD`
- [ ] Optional signing identity secret is configured if the default identity is
      not sufficient:
  - [ ] `DEVELOPER_ID_APPLICATION`

## Workflow Run

- Workflow: **Actions > Staged Release > Run workflow**
- Workflow run URL:
- GitHub draft release URL:
- Published release URL:
- Artifact URL:
- Checksum URL:
- DMG filename:
- Checksum filename:
- DMG SHA256:

Expected workflow checks:

- [ ] `scripts/prepare-release-signing.sh`
- [ ] `make build-dev`
- [ ] `make test`
- [ ] `make cli-test`
- [ ] `make release-dry-run`
- [ ] `make release-dmg VERSION=<version> BUILD=<build>`
- [ ] Upload release artifacts for review
- [ ] Create or update staged GitHub Release

## Artifact Smoke Checks

Download the DMG and checksum from the draft release, published release, or
workflow artifact, then run:

```sh
shasum -a 256 -c RedditReminder-*-macos.dmg.sha256
spctl -a -vv -t open --context context:primary-signature RedditReminder-*-macos.dmg
xcrun stapler validate RedditReminder-*-macos.dmg
```

Record results:

- [ ] Checksum passed.
- [ ] Gatekeeper validation passed.
- [ ] Stapler validation passed.
- [ ] DMG mounts.
- [ ] `RedditReminder.app` copies to `/Applications`.
- [ ] `RedditReminder.app` launches.
- [ ] Menu bar item appears.
- [ ] Popover opens.
- [ ] Settings open.
- [ ] Existing production data is readable.
- [ ] `RedditReminder Dev.app` installs and launches separately.
- [ ] Development data remains separate from production data.

Smoke notes:

```text

```

## Decision

Choose one:

- [ ] Publish draft release.
- [ ] Keep draft and fix release workflow or packaging.
- [ ] Delete/replace draft artifact before publication.
- [ ] Cut a new patch version.
- [ ] Blocked by external Apple/GitHub setup.

Decision rationale:

```text

```

Follow-up issue or PR:

-
