# T004 Secret And Workflow Handoff

Status: external setup required before the first draft Staged Release workflow
can run.

## Current Evidence

- `gh auth status` succeeds for `neonwatty` with `repo` and `workflow` scopes.
- `gh repo view --json nameWithOwner,defaultBranchRef,url` resolves
  `neonwatty/RedditReminder` with default branch `main`.
- `gh workflow list --all` currently lists only `CI`; the new
  `.github/workflows/release.yml` is still only in the local dirty worktree.
- `gh secret list --app actions` returned no configured Actions secret names.

## Required Before Draft Run

1. Commit and push the release-train changes, including:
   - `.github/workflows/release.yml`
   - `scripts/build-release-dmg.sh`
   - `scripts/prepare-release-signing.sh`
   - `ExportOptions.plist`
   - dev/prod target and storage separation changes
   - release runbook/checklist docs
2. Merge to `main` or otherwise make `release.yml` available on the repository
   default branch so GitHub Actions exposes the manual workflow.
3. Configure these GitHub Actions secrets by name only:
   - `APPLE_TEAM_ID`
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_PRIVATE_KEY`
   - `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`
   - `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`
   - `KEYCHAIN_PASSWORD`
4. Configure `DEVELOPER_ID_APPLICATION` only if the default identity selector
   `Developer ID Application` is insufficient.

Do not write secret values into repo files, GoalBuddy receipts, issues, PR
comments, or release checklists.

## First Draft Run Inputs

Recommended first rehearsal values after setup:

- `version`: the first intended release version, for example `0.1.0`
- `build`: blank to use the GitHub run number, or an explicit integer
- `ref`: `main` after the release-train PR merges
- `draft`: `true`
- `prerelease`: `false`

## Expected Evidence To Capture

- Staged Release workflow run URL.
- Draft GitHub Release URL.
- Workflow artifact URL.
- DMG filename.
- Checksum filename.
- Whether every release workflow step passed.
