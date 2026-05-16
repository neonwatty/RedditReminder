# UX Follow-Ups Deferred From This Tranche

These items were intentionally deferred by `T008` after safer local UX slices passed.

## Month Planner / Wider Planner

Reason deferred: T005 improved 7-day planner actionability without needing new scenes or wide layouts.

Future acceptance criteria:
- Shows at least 28 days plus leading/trailing context.
- Each visible day cell shows date, posting-window count, and at least one identifiable channel without hover.
- Overflow has a deterministic drill-in or filter path.
- Contextual create-capture from a month cell or window preselects the relevant subreddit.
- Desktop and compact-width QA screenshots show no text overlap.

## Detachable Planner Window

Reason deferred: No current blocker requires a new scene/window.

Future acceptance criteria:
- Opening and closing the detached planner preserves planner route state.
- Contextual create-capture from detached planner preserves selected subreddit context.
- Unsaved capture draft state is not lost when moving between popover and detached planner flows.
- Scripted QA covers open detached planner, create capture from a window, save/cancel, and return to Queue.

## Native Settings Window

Reason deferred: Current Preferences surface is still functional, and this tranche prioritized recovery, actionability, accessibility, and validation.

Future acceptance criteria:
- General, Notifications, Backup, and Hotkeys are reachable in native window chrome.
- Menu item and popover Settings entry open the same settings surface.
- Existing preferences tests are migrated or preserved with equivalent assertions.
- Keyboard focus order reaches every primary control without pointer interaction.

## Major Navigation / Data Model Changes

Reason deferred or blocked: No completed UX slice required schema or navigation architecture changes.

Future acceptance criteria:
- Any proposed navigation restructure must include before/after route map, migration plan, and regression tests for Queue, Planner, Channels, Posted, and capture editing.
- Any proposed data model change must include migration tests and rollback risk notes before implementation.
