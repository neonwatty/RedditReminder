# RedditReminder Staged Release Rehearsal

Prepare and execute the first staged release rehearsal for RedditReminder after
the release-train implementation. The outcome is not merely another workflow
change; the outcome is evidence that the staged release path can produce a
signed/notarized draft production artifact, that the artifact can be smoke-tested,
and that the operator has a clear publish-or-fix decision.

## Intake

- Original request: "great - lets do that" in response to organizing the staged release rehearsal as GoalBuddy prep.
- Interpreted outcome: Create a GoalBuddy board for running the first staged release rehearsal end to end.
- Input shape: existing_plan
- Audience: RedditReminder maintainer and release operator.
- Authority: requested.
- Proof type: artifact plus decision.
- Completion proof: A draft GitHub Release or explicit external blocker is recorded with evidence; if a draft artifact exists, checksum/Gatekeeper/stapler/install/launch/dev-prod coexistence smoke checks are recorded; a Judge receipt states publish, fix, or blocked with exact missing external requirement.
- Goal oracle: Release rehearsal evidence, not intent. The board is complete only when receipts map the staged workflow run, produced artifacts or external blocker, smoke results when available, and a publish/fix decision.
- Likely misfire: Stopping after writing a checklist or telling the operator what to do while no draft release evidence, smoke evidence, or blocker receipt exists.

## Existing Plan Facts

1. A staged manual release workflow is preferred over semantic-release.
2. Production artifacts should be signed and notarized Developer ID DMGs.
3. Releases should start as draft GitHub Releases for smoke testing.
4. The dev app should continue to coexist with production.
5. Secrets must never be stored in the repository or pasted into GoalBuddy files.
6. Missing Apple/GitHub credentials are blockers for the specific release-run task, not a reason to lose the rest of the rehearsal plan.

## Scope

In scope:

1. Validate the staged release workflow and runbook are ready enough for first use.
2. Add a release checklist artifact or issue template if the board decides it is useful before the first run.
3. Guide secret setup without reading or storing secret values.
4. Trigger or guide the draft staged release workflow.
5. Capture workflow/artifact URLs and smoke-test evidence.
6. Decide publish, fix, or blocked.

Out of scope:

1. Publishing a non-draft production release without explicit operator decision.
2. Storing certificates, private keys, API keys, passwords, or notarization credentials in repo files, chat, or GoalBuddy receipts.
3. Adding Homebrew or Sparkle distribution before the first GitHub draft release path is proven.
4. Reworking the release architecture unless rehearsal evidence proves a defect.

## Constraints

- Do not run destructive or externally publishing actions without explicit operator approval.
- Prefer draft releases and reviewable artifacts until smoke checks pass.
- Treat local inability to access GitHub Actions or Apple credentials as a task blocker with exact next step.
- Keep repo changes limited to checklist/runbook fixes unless a Judge task approves a narrow repair.
- Every completed task needs a receipt with commands, links, or blocker evidence.

## Starter Command

```text
/goal Follow docs/goals/redditreminder-staged-release-rehearsal/goal.md.
```
