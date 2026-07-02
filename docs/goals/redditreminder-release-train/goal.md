# RedditReminder Release Train

## Objective

Implement a regular release-train workflow for RedditReminder with separate production and development app identities, repeatable local release commands, CI verification, and a signed/notarized production packaging path suitable for GitHub releases.

## Original Request

"I think the regular release train is the right approach. You want to make a detailed plan to implement this? Using goalbuddy prep perhaps?"

## Intake Summary

- Input shape: `specific`
- Audience: RedditReminder maintainers and future release operators
- Authority: `requested`
- Proof type: `artifact`
- Completion proof: The repo contains verified dev/prod app flavor support, release packaging/notarization automation or documented credential blockers, CI/release workflow integration, and an operator runbook; a final audit maps passing checks and artifacts back to the requested release-train outcome.
- Goal oracle: A fresh checkout can run the documented development install path without colliding with production identity, and the production release path can be executed through local/GitHub commands up to any explicitly recorded credential or signing-secret boundary.
- Likely misfire: Producing only a written release plan or metadata-only semantic-release changes while leaving app identity, signing, notarization, and artifact publishing unresolved.
- Blind spots considered: Developer ID certificate availability, App Store Connect notarization credentials, hardened runtime requirements, LaunchAgent/menu bar naming collisions, SwiftData/store separation, CLI/store interactions, CI runner signing constraints, Homebrew cask timing, and preserving the existing agent CLI workflows.
- Existing plan facts: Use the proven usefoil/foil structure where production and development app identities are separate; production is signed/notarized and published on a regular train; development remains easy to install continuously for internal iteration.

## Goal Oracle

The oracle for this goal is:

`A verified release workflow where RedditReminder Dev and RedditReminder production can coexist, the dev build/install path is locally usable, the production release path produces or is ready to produce signed/notarized distributable artifacts, and CI/release documentation proves how the regular train is operated.`

The PM must keep comparing task receipts to this oracle. Planning, discovery, a passing tiny slice, or a clean-looking board is not enough. The goal finishes only when a final Judge/PM audit maps receipts and verification back to this oracle and records `full_outcome_complete: true`.

## Goal Kind

`specific`

## Current Tranche

Complete the first implementation tranche for release-train readiness:

1. Validate current repo release/signing/project structure and the specific Foil practices worth copying.
2. Choose the exact dev/prod flavor architecture for this XcodeGen project.
3. Implement development app identity separation with ergonomic local commands.
4. Add production packaging, signing, notarization, and release asset scaffolding.
5. Wire CI/GitHub release automation as far as local repo changes and documented secrets allow.
6. Document the regular train, manual checks, rollback, and credential setup.
7. Verify with local build/test commands and a final audit.

## Non-Negotiable Constraints

- Preserve existing app behavior and data unless a task explicitly documents and verifies an intentional dev/prod store separation change.
- Production and development builds must have distinct bundle identifiers and app display names.
- Production packaging must use hardened runtime and Developer ID signing/notarization when credentials are available.
- Do not commit secrets, certificates, provisioning profiles, API keys, or personal signing material.
- Keep the existing `redditreminder` CLI and agent workflows working.
- Prefer XcodeGen/project.yml-driven configuration over hand-editing generated Xcode project files.
- Prefer repeatable Makefile or script entry points over one-off release commands.
- Any non-dry-run publication, credential installation, or destructive local app data migration requires explicit human approval.

## Stop Rule

Stop only when a final audit proves the full original outcome is complete.

Do not stop after planning, discovery, or Judge selection if a safe Worker task can be activated.

Do not stop after a single verified Worker package when the broader owner outcome still has safe local follow-up work. Advance the board to the next highest-leverage safe Worker package and continue unless a phase, risk, rejected-verification, ambiguity, or final-completion review is due.

## Slice Sizing

Safe means bounded, explicit, verified, and reversible. It does not mean tiny.

A good task is the largest safe useful slice.

Worker slices should produce coherent milestones: dev/prod identity support, packaging automation, release workflow integration, and release documentation. Avoid one task per setting unless a risk boundary requires it.

## Board Health

The PM owns board health. If the board looks stale, misleading, offline, or inconsistent, run:

```bash
node /Users/neonwatty/.codex/plugins/cache/goalbuddy/goalbuddy/0.3.9/skills/goalbuddy/scripts/check-goal-state.mjs docs/goals/redditreminder-release-train
```

If the local board is running, compare `state.yaml` to the live board API. Repair only GoalBuddy control files unless an active Worker or PM task explicitly allows product-file edits.

## Canonical Board

Machine truth lives at:

`docs/goals/redditreminder-release-train/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins for task status, active task, receipts, verification freshness, and completion truth.

## Run Command

```text
/goal Follow docs/goals/redditreminder-release-train/goal.md.
```

## PM Loop

On every `/goal` continuation:

1. Read this charter.
2. Read `state.yaml`.
3. Run the bundled GoalBuddy update checker when available and mention a newer version without blocking.
4. Re-check the intake: original request, input shape, authority, proof, blind spots, existing plan facts, and likely misfire.
5. Work only on the active board task.
6. Assign Scout, Judge, Worker, or PM according to the task.
7. Write a compact task receipt.
8. Update the board.
9. If safe local work remains, choose the next largest reversible Worker package and continue unless blocked.
10. Review at phase, risk, rejected-verification, ambiguity, or final-completion boundaries; do not review every small Worker by habit.
11. Finish only with a Judge/PM audit receipt that maps receipts and verification back to the original user outcome and records `full_outcome_complete: true`.
