# T003 Worker Receipt: Settings Version Footer

## Result

Done.

## Changes

- Added `AppVersionInfo`, a small bundle metadata helper that reads:
  - `CFBundleDisplayName` / `CFBundleName`
  - `CFBundleShortVersionString`
  - `CFBundleVersion`
- Added a compact footer to `PreferencesView` below all Settings tabs.
- Added the stable accessibility identifier `preferences.footer.version`.
- Added unit tests for formatting, fallback behavior, blank-value handling, and the Preferences footer identifier.
- Regenerated `RedditReminder.xcodeproj/project.pbxproj` through `make build-dev` / `make test` so the tracked Xcode project includes the new source and test files.

## Bundle Metadata Inspection

The development app bundle currently reports:

- display name: `RedditReminder Dev`
- version: `0.1.0`
- build: `1`

The footer will therefore render `RedditReminder Dev 0.1.0 (1)` for the current debug development build. Production/release builds will render their own bundle values.

## Verification

- `git diff --check` passed.
- `make build-dev` passed.
- The first focused Xcode filter command returned success but ran `0` tests, so it was not counted as proof.
- `make test` passed and ran 454 Swift Testing tests, including the new `AppVersionInfo` cases.

## Notes

- No version/build values are hard-coded into the UI.
- The footer lives in Settings/Preferences, not the high-frequency menu bar popover.
