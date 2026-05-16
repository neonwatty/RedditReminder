# T008 Judge Decision: Architecture Gate

Decision: defer all architecture slices for this tranche.

Per-item decisions:
- Native Settings/window migration: defer. The current tranche improved popover and capture workflows without proving that a native Settings window is necessary for correctness or testability.
- Month planner view: defer. T005 improved 7-day planner actionability and visible calendar labels. A month view remains useful, but it is larger scope and should be designed with width, density, and navigation acceptance criteria.
- Detachable/wider planner: defer. No current blocker requires a new scene/window. This should be paired with the month-view decision if pursued.
- Major navigation restructuring: defer. Queue, planner, channels, posted, and capture flows now have safer recovery paths without changing navigation architecture.
- Data model changes: block for this tranche. No implemented slice required schema changes, and adding one would increase migration risk without direct UX proof.

No architecture Worker is approved. `T009` should be blocked by design and the goal should continue to follow-up recording and final audit.

Deferred acceptance criteria for future work:
- Month planner: render at least 28 days plus leading/trailing context; visible cells must show date, window count, and at least one identifiable channel without hover; overflow must have a deterministic drill-in path; desktop and compact-width QA screenshots must show no text overlap.
- Detachable planner: must preserve the current planner route state, support closing/reopening without losing unsaved capture draft state, and pass a scripted QA flow for opening a contextual capture from the detached surface.
- Native Settings: must expose General, Notifications, Backup, and Hotkeys in native window chrome; menu item and header entry must both open the same surface; existing preferences tests must continue to pass or be intentionally migrated.

Verification basis:
- `make test` passed for the completed safer slices, most recently 435 tests.
- No architecture work was implemented before this gate.
