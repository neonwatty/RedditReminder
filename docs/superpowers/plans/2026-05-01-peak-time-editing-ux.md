# Peak Time Editing UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make peak time editing frictionless by showing hours in local time, providing sensible defaults for blank subreddits, and adding preset buttons for common patterns.

**Architecture:** All changes stay within the existing `SubredditPeakSelection` utility (logic) and `SubredditRow` view (UI). Storage remains UTC — conversion happens at the display/input boundary. Presets and suggested defaults are defined as static data in the utility, applied via existing override mechanisms.

**Tech Stack:** Swift 6, SwiftUI, Foundation (TimeZone, Calendar), Swift Testing framework

---

## File Structure

**Modified files:**
- `Sources/Utilities/SubredditPeakSelection.swift` — add timezone conversion, presets, suggested defaults
- `Sources/Views/SubredditRow.swift` — local hour display, preset row, suggested state rendering
- `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift` — extend with conversion and preset tests

---

### Task 1: Timezone Conversion Functions

**Files:**
- Modify: `Sources/Utilities/SubredditPeakSelection.swift`
- Modify: `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift`

- [ ] **Step 1: Write failing tests for timezone conversion**

Add to `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift`:

```swift
import Foundation

@Test func localHourToUtcConvertsCorrectly() {
    // PDT is UTC-7
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    // In summer (PDT): local 9 AM = UTC 16
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    #expect(SubredditPeakSelection.localHourToUtc(9, timeZone: pdt, referenceDate: summer) == 16)
    #expect(SubredditPeakSelection.localHourToUtc(0, timeZone: pdt, referenceDate: summer) == 7)
    #expect(SubredditPeakSelection.localHourToUtc(20, timeZone: pdt, referenceDate: summer) == 3)
}

@Test func utcHourToLocalConvertsCorrectly() {
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    #expect(SubredditPeakSelection.utcHourToLocal(16, timeZone: pdt, referenceDate: summer) == 9)
    #expect(SubredditPeakSelection.utcHourToLocal(7, timeZone: pdt, referenceDate: summer) == 0)
    #expect(SubredditPeakSelection.utcHourToLocal(3, timeZone: pdt, referenceDate: summer) == 20)
}

@Test func timezoneConversionRoundTrips() {
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let ref = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    for hour in 0..<24 {
        let utc = SubredditPeakSelection.localHourToUtc(hour, timeZone: tokyo, referenceDate: ref)
        let back = SubredditPeakSelection.utcHourToLocal(utc, timeZone: tokyo, referenceDate: ref)
        #expect(back == hour)
    }
}

@Test func halfHourTimezoneConversion() {
    // India is UTC+5:30 — rounds to nearest hour
    let india = TimeZone(identifier: "Asia/Kolkata")!
    let ref = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    // Local 9 AM IST = UTC 3:30 AM → rounds to UTC 4
    let utc = SubredditPeakSelection.localHourToUtc(9, timeZone: india, referenceDate: ref)
    #expect(utc == 3 || utc == 4) // Either rounding direction is acceptable
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests/SubredditPeakSelectionTests 2>&1 | grep -E "(passed|failed)" | tail -5`
Expected: FAIL — functions don't exist.

- [ ] **Step 3: Implement conversion functions**

Add to `Sources/Utilities/SubredditPeakSelection.swift` after the existing `effectivePeakHours` method:

```swift
static func localHourToUtc(_ localHour: Int, timeZone: TimeZone = .current, referenceDate: Date = Date()) -> Int {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = timeZone
    let comps = cal.dateComponents([.year, .month, .day], from: referenceDate)
    var localComps = comps
    localComps.hour = localHour
    localComps.minute = 0
    guard let localDate = cal.date(from: localComps) else { return localHour }

    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(identifier: "UTC")!
    return utcCal.component(.hour, from: localDate)
}

static func utcHourToLocal(_ utcHour: Int, timeZone: TimeZone = .current, referenceDate: Date = Date()) -> Int {
    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(identifier: "UTC")!
    let comps = utcCal.dateComponents([.year, .month, .day], from: referenceDate)
    var utcComps = comps
    utcComps.hour = utcHour
    utcComps.minute = 0
    guard let utcDate = utcCal.date(from: utcComps) else { return utcHour }

    var localCal = Calendar(identifier: .gregorian)
    localCal.timeZone = timeZone
    return localCal.component(.hour, from: utcDate)
}

static func utcHoursToLocal(_ utcHours: [Int], timeZone: TimeZone = .current, referenceDate: Date = Date()) -> [Int] {
    utcHours.map { utcHourToLocal($0, timeZone: timeZone, referenceDate: referenceDate) }.sorted()
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests/SubredditPeakSelectionTests 2>&1 | grep -E "(passed|failed)" | tail -5`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Utilities/SubredditPeakSelection.swift Tests/RedditReminderTests/SubredditPeakSelectionTests.swift
git commit -m "feat: add local/UTC hour conversion to SubredditPeakSelection"
```

---

### Task 2: Preset Definitions and Application

**Files:**
- Modify: `Sources/Utilities/SubredditPeakSelection.swift`
- Modify: `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift`

- [ ] **Step 1: Write failing tests for presets**

Add to `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift`:

```swift
@Test func presetsDefineExpectedPatterns() {
    let presets = SubredditPeakSelection.presets
    #expect(presets.count == 4)
    #expect(presets[0].label == "Weekday AM")
    #expect(presets[0].days == ["mon", "tue", "wed", "thu", "fri"])
    #expect(presets[0].localHours == [8, 9, 10, 11])

    #expect(presets[1].label == "Weekday PM")
    #expect(presets[1].days == ["mon", "tue", "wed", "thu", "fri"])
    #expect(presets[1].localHours == [17, 18, 19, 20])

    #expect(presets[2].label == "Weekend midday")
    #expect(presets[2].days == ["sat", "sun"])
    #expect(presets[2].localHours == [10, 11, 12, 13, 14])

    #expect(presets[3].label == "Daily prime")
    #expect(presets[3].days == ["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
    #expect(presets[3].localHours == [9, 10, 11, 12])
}

@Test func applyPresetConvertsToUtc() {
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    let preset = SubredditPeakSelection.presets[0] // Weekday AM: local 8-11

    let result = SubredditPeakSelection.applyPreset(preset, timeZone: pdt, referenceDate: summer)

    #expect(result.days == ["mon", "tue", "wed", "thu", "fri"])
    // PDT is UTC-7: local 8=UTC15, 9=UTC16, 10=UTC17, 11=UTC18
    #expect(result.utcHours == [15, 16, 17, 18])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests/SubredditPeakSelectionTests 2>&1 | grep -E "(passed|failed)" | tail -5`
Expected: FAIL — `presets` and `applyPreset` don't exist.

- [ ] **Step 3: Implement preset types and application**

Add to `Sources/Utilities/SubredditPeakSelection.swift`:

```swift
struct PeakPreset {
    let label: String
    let days: [String]
    let localHours: [Int]
}

struct AppliedPreset {
    let days: [String]
    let utcHours: [Int]
}

static let presets: [PeakPreset] = [
    PeakPreset(label: "Weekday AM", days: ["mon", "tue", "wed", "thu", "fri"], localHours: [8, 9, 10, 11]),
    PeakPreset(label: "Weekday PM", days: ["mon", "tue", "wed", "thu", "fri"], localHours: [17, 18, 19, 20]),
    PeakPreset(label: "Weekend midday", days: ["sat", "sun"], localHours: [10, 11, 12, 13, 14]),
    PeakPreset(label: "Daily prime", days: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"], localHours: [9, 10, 11, 12]),
]

static func applyPreset(_ preset: PeakPreset, timeZone: TimeZone = .current, referenceDate: Date = Date()) -> AppliedPreset {
    let utcHours = preset.localHours.map { localHourToUtc($0, timeZone: timeZone, referenceDate: referenceDate) }.sorted()
    return AppliedPreset(days: preset.days, utcHours: utcHours)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests/SubredditPeakSelectionTests 2>&1 | grep -E "(passed|failed)" | tail -5`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Utilities/SubredditPeakSelection.swift Tests/RedditReminderTests/SubredditPeakSelectionTests.swift
git commit -m "feat: add peak time presets with local-to-UTC conversion"
```

---

### Task 3: Suggested Defaults

**Files:**
- Modify: `Sources/Utilities/SubredditPeakSelection.swift`
- Modify: `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift`

- [ ] **Step 1: Write failing tests for suggested defaults**

Add to `Tests/RedditReminderTests/SubredditPeakSelectionTests.swift`:

```swift
@Test func suggestedDefaultsReturnsWeekdayAMPreset() {
    let suggested = SubredditPeakSelection.suggestedDefaults(timeZone: .current)
    #expect(suggested.days == ["mon", "tue", "wed", "thu", "fri"])
    #expect(suggested.localHours == [8, 9, 10, 11])
}

@Test func suggestedDefaultsUtcMatchesPresetApplication() {
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!

    let suggested = SubredditPeakSelection.suggestedDefaults(timeZone: pdt, referenceDate: summer)
    let applied = SubredditPeakSelection.applyPreset(SubredditPeakSelection.presets[0], timeZone: pdt, referenceDate: summer)

    #expect(suggested.utcHours == applied.utcHours)
    #expect(suggested.days == applied.days)
}

@Test func needsSuggestedDefaultsReturnsTrueWhenBlank() {
    #expect(SubredditPeakSelection.needsSuggestedDefaults(override: nil, peakInfo: nil) == true)
    #expect(SubredditPeakSelection.needsSuggestedDefaults(override: ["mon"], peakInfo: nil) == false)
    let info = PeakInfo(peakDays: ["tue"], peakHoursUtc: [14])
    #expect(SubredditPeakSelection.needsSuggestedDefaults(override: nil, peakInfo: info) == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests/SubredditPeakSelectionTests 2>&1 | grep -E "(passed|failed)" | tail -5`
Expected: FAIL.

- [ ] **Step 3: Implement suggested defaults**

Add to `Sources/Utilities/SubredditPeakSelection.swift`:

```swift
struct SuggestedDefaults {
    let days: [String]
    let localHours: [Int]
    let utcHours: [Int]
}

static func suggestedDefaults(timeZone: TimeZone = .current, referenceDate: Date = Date()) -> SuggestedDefaults {
    let preset = presets[0] // Weekday AM
    let applied = applyPreset(preset, timeZone: timeZone, referenceDate: referenceDate)
    return SuggestedDefaults(days: applied.days, localHours: preset.localHours, utcHours: applied.utcHours)
}

static func needsSuggestedDefaults(override: [String]?, peakInfo: PeakInfo?) -> Bool {
    override == nil && peakInfo == nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests/SubredditPeakSelectionTests 2>&1 | grep -E "(passed|failed)" | tail -5`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Utilities/SubredditPeakSelection.swift Tests/RedditReminderTests/SubredditPeakSelectionTests.swift
git commit -m "feat: add suggested defaults for blank subreddits"
```

---

### Task 4: SubredditRow — Local Hour Display

**Files:**
- Modify: `Sources/Views/SubredditRow.swift:58-69,148-170,194-195`

- [ ] **Step 1: Change the "PEAK HOURS" header to show local timezone**

In `Sources/Views/SubredditRow.swift`, replace the "PEAK HOURS (UTC)" text (line 65):

```swift
// Old:
Text("PEAK HOURS (UTC)")
    .font(.system(size: 9, weight: .medium))
    .foregroundStyle(.secondary)
    .tracking(0.3)

// New:
Text("PEAK HOURS (local — \(TimeZone.current.abbreviation() ?? "UTC"))")
    .font(.system(size: 9, weight: .medium))
    .foregroundStyle(.secondary)
    .tracking(0.3)
```

- [ ] **Step 2: Add `effectivePeakHoursLocal` computed property**

Add after the existing `effectivePeakHours` computed property (around line 219):

```swift
private var effectivePeakHoursLocal: [Int] {
    SubredditPeakSelection.utcHoursToLocal(effectivePeakHours)
}
```

- [ ] **Step 3: Update `peakHourChips` to use local hours for display**

Replace `peakHourChips` (lines 148-170):

```swift
private var peakHourChips: some View {
    let columns = [GridItem(.adaptive(minimum: 30), spacing: 3)]
    let hours = SubredditPeakSelection.displayHours
    let localSelected = effectivePeakHoursLocal
    return LazyVGrid(columns: columns, spacing: 3) {
        ForEach(hours, id: \.self) { hour in
            let isOn = localSelected.contains(hour)
            Button(action: { toggleHourLocal(hour) }) {
                Text("\(hour)")
                    .font(.system(size: 9, weight: .medium))
                    .frame(minWidth: 24)
                    .padding(.vertical, 3)
                    .background(isOn ? Color.green.opacity(hasOverride ? 0.12 : 0.06) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isOn ? Color.green : Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                    .foregroundStyle(isOn ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 4: Replace `toggleHour` with `toggleHourLocal`**

Replace the existing `toggleHour` method (line 194-195):

```swift
// Old:
private func toggleHour(_ hour: Int) {
    sub.peakHoursUtcOverride = SubredditPeakSelection.toggledHour(
        hour, in: sub.peakHoursUtcOverride)
}

// New:
private func toggleHourLocal(_ localHour: Int) {
    let utcHour = SubredditPeakSelection.localHourToUtc(localHour)
    sub.peakHoursUtcOverride = SubredditPeakSelection.toggledHour(
        utcHour, in: sub.peakHoursUtcOverride)
}
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild build -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Sources/Views/SubredditRow.swift
git commit -m "feat: display peak hours in local timezone with UTC conversion on tap"
```

---

### Task 5: SubredditRow — Preset Buttons

**Files:**
- Modify: `Sources/Views/SubredditRow.swift`

- [ ] **Step 1: Add preset row above the day chips**

In `SubredditRow.swift`, in the expanded section (after the `Divider()` at line 56, before the "PEAK DAYS" label at line 58), insert the preset row:

```swift
Text("PRESETS")
    .font(.system(size: 9, weight: .medium))
    .foregroundStyle(.secondary)
    .tracking(0.3)

presetChips
```

- [ ] **Step 2: Implement `presetChips` view**

Add a new computed property after `eventSourceChips`:

```swift
private var presetChips: some View {
    HStack(spacing: 4) {
        ForEach(SubredditPeakSelection.presets, id: \.label) { preset in
            Button(action: { applyPreset(preset) }) {
                Text(preset.label)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 3: Implement `applyPreset` method**

Add after `toggleHourLocal`:

```swift
private func applyPreset(_ preset: SubredditPeakSelection.PeakPreset) {
    let applied = SubredditPeakSelection.applyPreset(preset)
    sub.peakDaysOverride = applied.days
    sub.peakHoursUtcOverride = applied.utcHours
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild build -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Sources/Views/SubredditRow.swift
git commit -m "feat: add preset buttons for quick peak time configuration"
```

---

### Task 6: SubredditRow — Suggested Defaults State

**Files:**
- Modify: `Sources/Views/SubredditRow.swift`

- [ ] **Step 1: Add `showsSuggested` computed property**

Add after `hasOverride`:

```swift
private var showsSuggested: Bool {
    SubredditPeakSelection.needsSuggestedDefaults(
        override: sub.peakDaysOverride ?? (sub.peakHoursUtcOverride != nil ? [] : nil),
        peakInfo: peakInfo
    )
}
```

- [ ] **Step 2: Update `effectivePeakDays` and `effectivePeakHoursLocal` to include suggested**

Replace the existing computed properties:

```swift
private var effectivePeakDays: [String] {
    if showsSuggested {
        return SubredditPeakSelection.suggestedDefaults().days
    }
    return SubredditPeakSelection.effectivePeakDays(override: sub.peakDaysOverride, peakInfo: peakInfo)
}

private var effectivePeakHours: [Int] {
    if showsSuggested {
        return SubredditPeakSelection.suggestedDefaults().utcHours
    }
    return SubredditPeakSelection.effectivePeakHours(override: sub.peakHoursUtcOverride, peakInfo: peakInfo)
}

private var effectivePeakHoursLocal: [Int] {
    if showsSuggested {
        return SubredditPeakSelection.suggestedDefaults().localHours
    }
    return SubredditPeakSelection.utcHoursToLocal(effectivePeakHours)
}
```

- [ ] **Step 3: Update chip opacity to reflect suggested state**

In `peakDayChips`, change the background opacity:

```swift
// Old:
.background(
    isOn ? AppColors.redditOrange.opacity(hasOverride ? 0.12 : 0.06) : Color.clear
)

// New:
.background(
    isOn ? AppColors.redditOrange.opacity(showsSuggested ? 0.04 : (hasOverride ? 0.12 : 0.06)) : Color.clear
)
```

In `peakHourChips`, change the background opacity:

```swift
// Old:
.background(isOn ? Color.green.opacity(hasOverride ? 0.12 : 0.06) : Color.clear)

// New:
.background(isOn ? Color.green.opacity(showsSuggested ? 0.04 : (hasOverride ? 0.12 : 0.06)) : Color.clear)
```

- [ ] **Step 4: Add "(suggested)" label to headers when in suggested state**

Update the "PEAK DAYS" header:

```swift
HStack(spacing: 4) {
    Text("PEAK DAYS")
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.secondary)
        .tracking(0.3)
    if showsSuggested {
        Text("(suggested)")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
}
```

Update the "PEAK HOURS" header similarly:

```swift
HStack(spacing: 4) {
    Text("PEAK HOURS (local — \(TimeZone.current.abbreviation() ?? "UTC"))")
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.secondary)
        .tracking(0.3)
    if showsSuggested {
        Text("(suggested)")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
}
```

- [ ] **Step 5: Update `toggleDay` and `toggleHourLocal` to commit suggested on first interact**

Replace `toggleDay`:

```swift
private func toggleDay(_ day: String) {
    if showsSuggested {
        let suggested = SubredditPeakSelection.suggestedDefaults()
        sub.peakDaysOverride = SubredditPeakSelection.toggledDay(day, in: suggested.days)
        sub.peakHoursUtcOverride = suggested.utcHours
    } else {
        sub.peakDaysOverride = SubredditPeakSelection.toggledDay(day, in: sub.peakDaysOverride)
    }
}
```

Replace `toggleHourLocal`:

```swift
private func toggleHourLocal(_ localHour: Int) {
    let utcHour = SubredditPeakSelection.localHourToUtc(localHour)
    if showsSuggested {
        let suggested = SubredditPeakSelection.suggestedDefaults()
        sub.peakDaysOverride = suggested.days
        sub.peakHoursUtcOverride = SubredditPeakSelection.toggledHour(utcHour, in: suggested.utcHours)
    } else {
        sub.peakHoursUtcOverride = SubredditPeakSelection.toggledHour(utcHour, in: sub.peakHoursUtcOverride)
    }
}
```

- [ ] **Step 6: Build and run full tests**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests 2>&1 | grep -E "(Test run|passed|failed)" | tail -3`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Views/SubredditRow.swift
git commit -m "feat: show suggested defaults for blank subreddits with commit-on-first-interact"
```

---

### Task 7: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `xcodebuild test -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -only-testing RedditReminderTests 2>&1 | grep -E "(Test run|passed|failed)" | tail -3`
Expected: All tests pass, no failures.

- [ ] **Step 2: Run full build**

Run: `xcodebuild build -scheme RedditReminder -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: BUILD SUCCEEDED.
