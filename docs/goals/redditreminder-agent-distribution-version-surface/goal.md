# RedditReminder Agent Distribution and Version Surface

## Objective

Add a visible app version/build surface and create an agent-facing distribution path that explains how AI agents should use RedditReminder safely through its CLI, with a clear decision on whether the first artifact should be a skill only or a plugin-wrapped skill.

## Original Request

"Can you remind me how we distribute skills or a plugin that explains to an agent how they can use the app? And also, where's the version number in the app? I'm not seeing it anywhere. Should we put it at the bottom in the footer of the app?" Then: "Great - plan this out using goalbuddy prep please."

## Intake Summary

- Input shape: `specific`
- Audience: RedditReminder maintainers and future AI agents/Codex sessions that interact with the app
- Authority: `requested`
- Proof type: `artifact`
- Completion proof: The app visibly shows version/build metadata in an appropriate support surface, and the repo contains a validated agent-facing skill/plugin distribution artifact or a documented decision with install/use instructions.
- Goal oracle: A final audit verifies the visible app version/build against bundle metadata, validates the agent guidance artifact structure, confirms docs explain distribution/installation, and confirms checks pass.
- Likely misfire: Adding version text to a high-use popover footer in a way that clutters the posting workflow, or creating a generic plugin/skill that duplicates `AGENTS.md` without giving agents actionable CLI workflow guidance.
- Blind spots considered: whether the version belongs in the main popover or Settings; whether the agent artifact should be repo-local docs, a Codex skill, a marketplace plugin, or both; how to keep production and development app identities clear; how to verify generated version text uses bundle metadata rather than hard-coded release numbers.
- Existing plan facts:
  - `AGENTS.md` already instructs agents to use the `redditreminder` CLI.
  - The app version/build is in bundle metadata but is not visibly rendered in the current UI.
  - The recommended UI direction is a small Settings footer, not the main popover footer.
  - A skill is the likely first distribution artifact; a plugin is useful if we want installable/shareable packaging around that skill.
  - If a plugin is created, plugin-creator instructions and validation should be followed.
  - If a skill is created, skill-creator instructions and validation should be followed.

## Goal Oracle

The oracle for this goal is:

`A reviewer can launch or inspect RedditReminder and see version/build metadata sourced from bundle values, then install or inspect an agent-facing RedditReminder skill/plugin artifact that tells agents to use the CLI safely, including bootstrap/discovery, dry-run/validation, isolated stores for tests, release-train boundaries, and no-secret handling. Verification commands and any PR/issue links are recorded in state.yaml receipts.`

The PM must keep comparing task receipts to this oracle. Planning, discovery, a passing tiny slice, or a clean-looking board is not enough. The goal finishes only when a final Judge/PM audit maps receipts and verification back to this oracle and records `full_outcome_complete: true`.

## Goal Kind

`specific`

## Current Tranche

Complete the first practical slice end to end:

1. Confirm the current app version/build data path and best UI placement.
2. Implement a visible version/build footer in the Settings/Preferences surface using bundle metadata.
3. Create and validate a repo-appropriate agent guidance artifact, starting with a skill unless Scout/Judge finds a plugin is necessary for the current distribution goal.
4. Document how maintainers distribute/use the artifact.
5. Verify with focused tests or app inspection plus artifact validation.
6. Publish the changes through the repo's normal PR flow when ready.

## Non-Negotiable Constraints

- Keep the main popover focused on posting workflow; do not add low-value metadata noise there unless later evidence overturns the Settings-footer recommendation.
- Do not hard-code `0.1.0` or a specific build number in UI; read from bundle metadata.
- Keep the production and development app identities clear.
- Preserve existing `AGENTS.md` CLI rules and prefer the `redditreminder` CLI for agent interaction.
- Do not write secrets or notarization private values into any skill/plugin/docs artifact.
- Follow skill-creator instructions before creating/updating a skill.
- Follow plugin-creator instructions before creating/updating a plugin.
- Worker tasks may only edit explicitly allowed files and must verify changes.

## Stop Rule

Stop only when a final audit proves the full original outcome is complete.

Do not stop after planning, discovery, or Judge selection if a safe Worker task can be activated.

Do not stop after a single verified Worker package when the broader owner outcome still has safe local follow-up work. Advance the board to the next highest-leverage safe Worker package and continue unless a phase, risk, rejected-verification, ambiguity, or final-completion review is due.

## Slice Sizing

Safe means bounded, explicit, verified, and reversible. It does not mean tiny.

A good task is the largest safe useful slice. For this goal, the likely largest safe useful first implementation slice is the Settings version/build footer plus tests. The agent artifact may be a second Worker slice if Scout/Judge determines it touches different files and needs separate validation.

## Board Health

The PM owns board health. If the board looks stale, misleading, offline, or inconsistent, run:

```bash
node /Users/neonwatty/.codex/plugins/cache/goalbuddy/goalbuddy/0.3.9/skills/goalbuddy/scripts/check-goal-state.mjs docs/goals/redditreminder-agent-distribution-version-surface
```

Repair only GoalBuddy control files unless an active Worker or PM task explicitly allows product-file edits.

## Canonical Board

Machine truth lives at:

`docs/goals/redditreminder-agent-distribution-version-surface/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins for task status, active task, receipts, verification freshness, and completion truth.

## Run Command

```text
/goal Follow docs/goals/redditreminder-agent-distribution-version-surface/goal.md.
```

## PM Loop

On every `/goal` continuation:

1. Read this charter.
2. Read `state.yaml`.
3. Run the bundled GoalBuddy update checker when available and mention a newer version without blocking.
4. Work only on the active board task.
5. Assign Scout, Judge, Worker, or PM according to the task.
6. Write a compact task receipt.
7. Update the board.
8. Continue into the next safe task until the oracle is satisfied or a real blocker is recorded.
9. Finish only with a Judge/PM audit receipt that maps receipts and verification back to the original user outcome and records `full_outcome_complete: true`.
