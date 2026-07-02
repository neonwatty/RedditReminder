# T001 Scout Map

## Current RedditReminder Release Surface

- `project.yml` defines one production app target, `RedditReminder`, with `PRODUCT_BUNDLE_IDENTIFIER` effectively fixed at `com.neonwatty.RedditReminder` through the generated `Info.plist` properties. It also defines one tool target, `RedditReminderCLI`, with `com.neonwatty.RedditReminderCLI`.
- `project.yml` sets `MARKETING_VERSION: "0.1.0"`, `CURRENT_PROJECT_VERSION: "1"`, `CODE_SIGN_STYLE: Automatic`, `CODE_SIGN_IDENTITY: "Apple Development"`, `DEVELOPMENT_TEAM: B3A6AN2HA4`, and `ENABLE_HARDENED_RUNTIME: YES`.
- `Sources/Info.plist` duplicates fixed bundle metadata: `CFBundleDisplayName`, `CFBundleName`, `CFBundleIdentifier`, `CFBundleShortVersionString`, and `CFBundleVersion`. This should become build-setting-driven before dev/prod flavors are introduced.
- `RedditReminder.entitlements` enables app sandbox, user-selected read/write files, and network client access. There is a mismatch risk because `project.yml` also sets `ENABLE_APP_SANDBOX: NO`; implementation should verify which setting Xcode actually applies.
- `Makefile` has local build/test/install targets and explicit ad-hoc overrides for Debug, CLI, unit tests, and UI tests. Production `make build` uses Release and project signing settings, but there is no archive/export/notarize/package target.
- `Makefile` uses a single `APP_NAME := RedditReminder` and `LABEL := com.neonwatty.$(APP_NAME)`, so dev/prod coexistence currently has no app-name or LaunchAgent-label separation.
- `.github/workflows/ci.yml` runs lint, build, unit tests, CLI tests, UI tests, package metadata validation, file-size check, and semantic-release on pushes to `main`. The release job is metadata-only: it runs `npx semantic-release` but does not build, sign, notarize, package, checksum, or upload a Mac artifact.
- `.releaserc.json` only configures commit analysis, release notes, and GitHub release publishing.
- `package.json` uses semantic-release tooling and the placeholder version `0.0.0-semantically-released`.
- There are no current `ExportOptions.plist`, release DMG scripts, notarization scripts, appcast assets, release process docs, Homebrew cask files, or release asset workflows.

## App Data And CLI Surface

- App SwiftData defaults to `ModelContainer(for: schema)` unless `--ui-test-store` is passed. The default container is bundle-identity-sensitive at the system level, but media storage is not: `MediaStore()` defaults to `~/Library/Application Support/RedditReminder/media`.
- `AppModelContainerFactory.appSupportDirectory` points to `~/Library/Application Support/RedditReminder`.
- CLI default SwiftData path is `~/Library/Application Support/default.store`, while CLI media defaults to a sibling `media` directory only when `--store PATH` is provided. This is documented as reading/writing the same SwiftData store as the app, but the default paths appear inconsistent and should be treated as a release-train risk.
- CLI supports `--store PATH`, which is the safest way to target isolated dev/test stores without touching production data.
- UI tests already use `--ui-test-store`, and QA launch arguments are Debug-only.

## Foil Practices Worth Copying

- Foil uses separate XcodeGen app targets from the same source tree: `Foil` and `FoilDev`. The production target has `PRODUCT_NAME: Foil` and `PRODUCT_BUNDLE_IDENTIFIER: com.neonwatty.Foil`; the dev target has `PRODUCT_NAME: "Foil Dev"` and `PRODUCT_BUNDLE_IDENTIFIER: com.neonwatty.Foil.Dev`.
- Foil derives `CFBundleDisplayName`, `CFBundleShortVersionString`, and `CFBundleVersion` from build settings, avoiding hard-coded plist drift across flavors.
- Foil's README explicitly tells developers to install/start the dev flavor (`make install-dev`, `make start-dev`) and reserves tagged releases/Homebrew for production.
- Foil's Makefile centralizes prod/dev names, bundle IDs, schemes, signing identities, build paths, `build-dev`, `install-dev`, `start-dev`, `stop-dev`, and release preparation commands.
- Foil's release process is manual/tag-driven: prepare a release PR, merge through CI, tag the merged commit, then run a release workflow manually with version/build inputs.
- Foil's release workflow checks out the tag, verifies the tag SHA, ensures a GitHub Release exists, imports the Developer ID certificate from secrets, builds an archive, exports with `ExportOptions.plist`, creates a DMG, signs and notarizes it, staples and validates it, uploads the DMG and checksum, and optionally updates Homebrew.
- Foil has a separate notarized QA workflow that uses the same trust path without publishing a public GitHub release. This is useful but can be a second tranche for RedditReminder if production release scaffolding is large.
- Foil documents release secrets and release QA gates in `docs/release-process.md`.

## Practices To Defer

- Sparkle/appcast support should be deferred unless RedditReminder wants in-app updates. It adds key management, appcast signing, and UI/update behavior not required for the requested release train.
- Homebrew cask publishing can be documented as a follow-up. The first tranche should publish signed/notarized GitHub release assets and checksums.
- A notarized QA workflow is valuable but not required before the basic production release train works.
- Foil's local signing keychain flow is heavier than RedditReminder needs initially because this repo already uses ad-hoc signing for debug/test targets.

## Verification Commands Available Today

- `make generate`
- `make build-debug`
- `make build-cli`
- `make test`
- `make cli-test`
- `make ui-test`
- `npm ci`
- `node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8')); JSON.parse(require('fs').readFileSync('package-lock.json', 'utf8')); JSON.parse(require('fs').readFileSync('.releaserc.json', 'utf8')); require('./commitlint.config.cjs');"`
- `xcodebuild -showBuildSettings -project RedditReminder.xcodeproj -scheme RedditReminder -configuration Debug`
- `plutil -p Sources/Info.plist`
- `plutil -p RedditReminder.entitlements`
- Future release verification should add `codesign --verify --deep --strict`, `codesign -dvvv --entitlements :-`, `spctl -a -vv`, `xcrun stapler validate`, and `shasum -a 256`.

## Risks And Decisions For Judge

- Prefer a separate `RedditReminderDev` XcodeGen target sharing `Sources` over build-configuration conditionals. This mirrors Foil and makes scheme/build settings explicit.
- Convert hard-coded Info.plist version and bundle fields to build settings before adding flavors: `$(PRODUCT_BUNDLE_IDENTIFIER)`, `$(PRODUCT_NAME)`, `$(MARKETING_VERSION)`, and `$(CURRENT_PROJECT_VERSION)`.
- Add dev Makefile targets: `build-dev`, `install-dev`, `start-dev`, `stop-dev`, and possibly `qa-dev`.
- Use `/Applications/RedditReminder Dev.app` or `~/Applications/RedditReminder Dev.app` consistently. Current repo installs to `~/Applications`; Foil installs to `/Applications`. Preserve current install location unless the release plan intentionally changes it.
- Add a dev-specific media root and app support directory if the app should guarantee data separation. Bundle ID alone may separate SwiftData default storage, but current custom media path does not.
- Decide whether CLI default should continue pointing at the production store or gain an explicit dev-target option. To avoid accidentally changing agent behavior, keep CLI default stable and document `--store PATH` for dev/test unless a later task safely aligns defaults.
- Production signing requires secrets: `DEVELOPER_ID_CERT_BASE64`, `DEVELOPER_ID_CERT_PASSWORD`, `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_PRIVATE_KEY`.
- Release workflow must not publish a production asset unless signing, notarization, stapling, and validation succeed.

## Recommended Worker Slices

1. Dev/prod app identity foundation: separate dev target, build-setting-driven Info.plist values, dev Makefile commands, app/media support separation if low-risk, and build-setting verification.
2. Production packaging scaffolding: `ExportOptions.plist`, release DMG or ZIP script, signing/notarization/checksum validation, and local dry-run or syntax-test path.
3. GitHub release workflow: guarded tag/manual workflow that imports certificate, builds/notarizes/uploads assets, and keeps semantic-release behavior coherent.
4. Runbook: release cadence, prepare/tag/build/publish procedure, required secrets, smoke checks, rollback, and deferred Homebrew/Sparkle notes.
