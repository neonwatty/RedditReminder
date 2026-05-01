# Peak Time Editing UX Design

**Date:** 2026-05-01
**Status:** Approved

## Overview

Improve the peak time editing experience in the Channels tab by: (1) displaying hours in the user's local timezone instead of UTC, (2) providing sensible defaults for subreddits without bundled data, and (3) adding preset buttons for common scheduling patterns.

---

## 1. Local Timezone Display

**Problem:** Peak hours are stored and displayed in UTC. Users must mentally convert to their local timezone when picking hours.

**Design:**

- All storage remains UTC — no data migration needed.
- The hour chip grid displays local-time hours (0-23). When the user taps hour "9" (local), it stores the UTC equivalent.
- Add conversion functions to `SubredditPeakSelection`:
  - `localHourToUtc(_ localHour: Int, timeZone: TimeZone = .current) -> Int`
  - `utcHourToLocal(_ utcHour: Int, timeZone: TimeZone = .current) -> Int`
- `effectivePeakHours` continues to return UTC hours internally. A new `effectivePeakHoursLocal` computed property in `SubredditRow` maps them to local for chip display.
- The section header changes from "PEAK HOURS (UTC)" to "PEAK HOURS (local — \(TimeZone.current.abbreviation() ?? ""))" so there's no ambiguity.
- `toggleHour` converts the tapped local hour to UTC before storing.

**Files affected:**
- `Sources/Utilities/SubredditPeakSelection.swift` — add conversion functions
- `Sources/Views/SubredditRow.swift` — display local hours, convert on tap

## 2. Sensible Defaults for Blank Subreddits

**Problem:** Subreddits not in `peak-times.json` start with zero days/hours selected. The user must tap each chip individually.

**Design:**

- When a subreddit has no bundled data (`peakInfo` is nil) and no user overrides, show a "suggested" state.
- The suggested defaults are "Weekday AM": Mon-Fri, 8-11 AM local (converted to UTC for storage).
- Suggested state renders chips at lower opacity (0.04 background instead of 0.12) with a "(suggested)" label next to the section header.
- The suggested days/hours are NOT persisted until the user interacts. First tap on any day or hour chip:
  1. Commits the full suggested set as the override
  2. Applies the user's tap (toggle) on top
- This means one tap gives the user "suggested minus one" or "suggested plus one" — they're immediately in override mode with a reasonable starting point.

**Files affected:**
- `Sources/Utilities/SubredditPeakSelection.swift` — add suggested defaults logic
- `Sources/Views/SubredditRow.swift` — render suggested state, commit-on-first-interact

## 3. Preset Buttons

**Problem:** Setting common patterns like "weekday mornings" requires 5 day taps + 3-4 hour taps. Too many taps for the most common configurations.

**Design:**

- Add a row of compact pill buttons above the day chips in the expanded `SubredditRow`.
- Four presets:
  - **"Weekday AM"** — Mon-Fri, 8-11 AM local
  - **"Weekday PM"** — Mon-Fri, 5-8 PM local
  - **"Weekend midday"** — Sat-Sun, 10 AM-2 PM local
  - **"Daily prime"** — Mon-Sun, 9 AM-12 PM local
- Tapping a preset replaces the current selection (sets both `peakDaysOverride` and `peakHoursUtcOverride` in one action).
- Hours in presets are local — converted to UTC on apply using the conversion functions from section 1.
- Styled as small pills (similar to existing chip styling but with a distinct "preset" appearance): text-only, no icon, `.quaternary` background, subtle border. Active state not needed since presets are actions, not selections.

**Files affected:**
- `Sources/Utilities/SubredditPeakSelection.swift` — define preset configurations, apply function
- `Sources/Views/SubredditRow.swift` — render preset row, wire tap actions

---

## Testing

- **SubredditPeakSelection timezone conversion tests:** `localHourToUtc` and `utcHourToLocal` with various timezone offsets, including half-hour timezones (India +5:30) and DST transitions.
- **Preset application tests:** Each preset produces the expected UTC hours and day arrays for a given timezone.
- **Suggested defaults tests:** Verify the suggested defaults produce correct UTC hours for the user's timezone, and that first-interact commit works correctly.

**Test file:** `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift` (extend existing)

---

## Out of Scope

- Fetching peak times from Reddit's API
- Per-subreddit timezone overrides (always uses system timezone)
- Custom user-defined presets
- Persisting suggested defaults before user interaction
