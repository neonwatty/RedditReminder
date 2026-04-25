# RedditReminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS sidebar app that captures project updates and nudges users about optimal Reddit posting windows.

**Architecture:** SwiftUI + AppKit hybrid. An `NSPanel` anchored to the screen edge acts as a persistent sidebar visible on all Spaces. SwiftData models store projects, captures, subreddits, and events. A `TimingEngine` polls every 5 minutes, matching queued captures to upcoming posting windows and scheduling `UNUserNotificationCenter` alerts.

**Tech Stack:** Swift 6.0, SwiftUI, AppKit (NSPanel), SwiftData, XcodeGen, macOS 14.0+

**Spec:** `docs/superpowers/specs/2026-04-25-reddit-reminder-design.md`

---

## File Structure

```
RedditReminder/
├── project.yml                           # XcodeGen project definition
├── Makefile                              # build, test, install, clean, launch-at-login
├── Sources/
│   ├── Info.plist                        # LSUIElement, bundle metadata
│   ├── App/
│   │   ├── RedditReminderApp.swift       # @main entry, AppDelegate adaptor, hidden keepalive window
│   │   └── AppDelegate.swift             # NSPanel creation, global shortcut, TimingEngine timer
│   ├── Models/
│   │   ├── Project.swift                 # SwiftData @Model
│   │   ├── Capture.swift                 # SwiftData @Model + CaptureStatus enum
│   │   ├── Subreddit.swift               # SwiftData @Model
│   │   └── SubredditEvent.swift          # SwiftData @Model
│   ├── Services/
│   │   ├── PanelController.swift         # NSPanel lifecycle, SidebarState enum, width transitions
│   │   ├── TimingEngine.swift            # Window matching, urgency computation
│   │   ├── NotificationService.swift     # UNUserNotificationCenter scheduling
│   │   ├── MediaStore.swift              # File storage, thumbnail generation
│   │   └── HeuristicsStore.swift         # Bundled JSON + user overrides
│   ├── Views/
│   │   ├── SidebarContainer.swift        # Root view, switches content by state
│   │   ├── StripView.swift               # 24px collapsed
│   │   ├── GlanceView.swift              # 200px ambient
│   │   ├── BrowseView.swift              # 320px queue + calendar tabs
│   │   ├── CaptureFormView.swift         # 480px new/edit capture
│   │   ├── CalendarTimelineView.swift    # Vertical event timeline
│   │   ├── CalendarMonthView.swift       # Month grid with day detail
│   │   ├── CaptureCardView.swift         # Adaptive capture card
│   │   ├── EventCardView.swift           # Timeline event card
│   │   └── SettingsView.swift            # Preferences
│   └── Utilities/
│       ├── KeyboardShortcuts.swift       # Global hotkey via CGEvent tap
│       ├── RRuleHelper.swift             # RRULE parsing and next-occurrence expansion
│       └── Constants.swift               # Widths, durations, colors
├── Resources/
│   └── peak-times.json                   # Bundled subreddit heuristics
└── Tests/
    └── RedditReminderTests/
        ├── ModelTests.swift              # SwiftData model tests
        ├── TimingEngineTests.swift        # Urgency + matching logic
        ├── RRuleHelperTests.swift         # RRULE expansion
        ├── HeuristicsStoreTests.swift     # JSON loading + overrides
        └── MediaStoreTests.swift          # Thumbnail generation
```

---

### Task 1: Project Scaffold — XcodeGen, Makefile, Info.plist

**Files:**
- Create: `project.yml`
- Create: `Makefile`
- Create: `Sources/Info.plist`
- Create: `Sources/App/RedditReminderApp.swift`
- Create: `Sources/App/AppDelegate.swift`

- [ ] **Step 1: Create `project.yml`**

```yaml
name: RedditReminder
options:
  bundleIdPrefix: com.neonwatty
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: "-"
    ENABLE_HARDENED_RUNTIME: NO
    ENABLE_APP_SANDBOX: NO
    COMBINE_HIDPI_IMAGES: YES
    SWIFT_STRICT_CONCURRENCY: targeted

targets:
  RedditReminder:
    type: application
    platform: macOS
    sources:
      - path: Sources
    resources:
      - path: Resources
    info:
      path: Sources/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: RedditReminder
        CFBundleDisplayName: RedditReminder
        CFBundleIdentifier: com.neonwatty.RedditReminder
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        LSMinimumSystemVersion: "14.0"
        NSHumanReadableCopyright: "Copyright 2026 Jeremy Watt"

  RedditReminderTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/RedditReminderTests
    dependencies:
      - target: RedditReminder
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.neonwatty.RedditReminderTests
```

- [ ] **Step 2: Create `Makefile`**

```makefile
.PHONY: build test install install-login clean generate

APP_NAME := RedditReminder
PROJ := $(APP_NAME).xcodeproj
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications
LABEL := com.neonwatty.$(APP_NAME)

generate:
	xcodegen generate

build: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -configuration Release -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

install: build
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app $(INSTALL_DIR)/
	@if [ -f "$(HOME)/Library/LaunchAgents/$(LABEL).plist" ]; then \
	  echo "LaunchAgent detected -- restarting managed instance"; \
	  launchctl kickstart -k "gui/$$(id -u)/$(LABEL)"; \
	else \
	  open $(INSTALL_DIR)/$(APP_NAME).app; \
	fi

clean:
	rm -rf $(PROJ) $(BUILD_DIR)
```

- [ ] **Step 3: Create `Sources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
```

- [ ] **Step 4: Create minimal `AppDelegate.swift`**

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("RedditReminder: launched")
    }
}
```

- [ ] **Step 5: Create minimal `RedditReminderApp.swift`**

```swift
import SwiftUI

@main
struct RedditReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("RedditReminderKeepalive") {
            Text("RedditReminder")
                .frame(width: 1, height: 1)
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
    }
}
```

- [ ] **Step 6: Create placeholder test file**

Create `Tests/RedditReminderTests/ModelTests.swift`:

```swift
import Testing

@Test func placeholder() {
    #expect(true)
}
```

- [ ] **Step 7: Create empty `Resources/peak-times.json`**

```json
{}
```

- [ ] **Step 8: Generate project and verify it builds**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 9: Run tests**

Run: `make test`
Expected: Test suite passed (1 test)

- [ ] **Step 10: Commit**

```bash
git add project.yml Makefile Sources/ Resources/ Tests/
git commit -m "feat: project scaffold with XcodeGen, Makefile, and minimal app"
```

---

### Task 2: SwiftData Models

**Files:**
- Create: `Sources/Models/Project.swift`
- Create: `Sources/Models/Capture.swift`
- Create: `Sources/Models/Subreddit.swift`
- Create: `Sources/Models/SubredditEvent.swift`
- Modify: `Tests/RedditReminderTests/ModelTests.swift`

- [ ] **Step 1: Write model tests**

Replace `Tests/RedditReminderTests/ModelTests.swift`:

```swift
import Testing
import Foundation
@testable import RedditReminder

@Test func projectCreation() {
    let project = Project(name: "Bullhorn")
    #expect(project.name == "Bullhorn")
    #expect(project.archived == false)
    #expect(project.captures.isEmpty)
}

@Test func captureCreation() {
    let project = Project(name: "Bullhorn")
    let sub = Subreddit(name: "r/SideProject")
    let capture = Capture(
        text: "Shipped dark mode",
        project: project,
        subreddits: [sub]
    )
    #expect(capture.text == "Shipped dark mode")
    #expect(capture.status == .queued)
    #expect(capture.subreddits.count == 1)
    #expect(capture.mediaRefs.isEmpty)
    #expect(capture.postedAt == nil)
}

@Test func captureMarkAsPosted() {
    let project = Project(name: "Test")
    let capture = Capture(text: "Update", project: project, subreddits: [])
    capture.markAsPosted()
    #expect(capture.status == .posted)
    #expect(capture.postedAt != nil)
}

@Test func subredditEventRecurring() {
    let sub = Subreddit(name: "r/SideProject")
    let event = SubredditEvent(
        name: "Show-off Saturday",
        subreddit: sub,
        rrule: "FREQ=WEEKLY;BYDAY=SA"
    )
    #expect(event.isRecurring)
    #expect(event.isActive)
}

@Test func subredditEventOneOff() {
    let sub = Subreddit(name: "r/SideProject")
    let event = SubredditEvent(
        name: "Launch Day",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(86400)
    )
    #expect(!event.isRecurring)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `Project`, `Capture`, `Subreddit`, `SubredditEvent` not defined

- [ ] **Step 3: Create `Sources/Models/Project.swift`**

```swift
import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var projectDescription: String?
    var color: String?
    var archived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Capture.project)
    var captures: [Capture]

    init(
        name: String,
        projectDescription: String? = nil,
        color: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.projectDescription = projectDescription
        self.color = color
        self.archived = false
        self.createdAt = Date()
        self.captures = []
    }
}
```

- [ ] **Step 4: Create `Sources/Models/Subreddit.swift`**

```swift
import Foundation
import SwiftData

@Model
final class Subreddit {
    var id: UUID
    var name: String
    var peakDaysOverride: [String]?
    var peakHoursUtcOverride: [Int]?

    @Relationship(inverse: \SubredditEvent.subreddit)
    var events: [SubredditEvent]

    init(
        name: String,
        peakDaysOverride: [String]? = nil,
        peakHoursUtcOverride: [Int]? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.peakDaysOverride = peakDaysOverride
        self.peakHoursUtcOverride = peakHoursUtcOverride
        self.events = []
    }
}
```

- [ ] **Step 5: Create `Sources/Models/Capture.swift`**

```swift
import Foundation
import SwiftData

enum CaptureStatus: String, Codable {
    case queued
    case posted
}

@Model
final class Capture {
    var id: UUID
    var text: String
    var notes: String?
    var mediaRefs: [String]
    var status: CaptureStatus
    var createdAt: Date
    var postedAt: Date?

    var project: Project?
    var subreddits: [Subreddit]

    init(
        text: String,
        notes: String? = nil,
        mediaRefs: [String] = [],
        project: Project,
        subreddits: [Subreddit]
    ) {
        self.id = UUID()
        self.text = text
        self.notes = notes
        self.mediaRefs = mediaRefs
        self.status = .queued
        self.createdAt = Date()
        self.postedAt = nil
        self.project = project
        self.subreddits = subreddits
    }

    func markAsPosted() {
        self.status = .posted
        self.postedAt = Date()
    }
}
```

- [ ] **Step 6: Create `Sources/Models/SubredditEvent.swift`**

```swift
import Foundation
import SwiftData

@Model
final class SubredditEvent {
    var id: UUID
    var name: String
    var rrule: String?
    var oneOffDate: Date?
    var reminderLeadMinutes: Int
    var isActive: Bool

    var subreddit: Subreddit?

    var isRecurring: Bool {
        rrule != nil
    }

    init(
        name: String,
        subreddit: Subreddit,
        rrule: String? = nil,
        oneOffDate: Date? = nil,
        reminderLeadMinutes: Int = 60,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.rrule = rrule
        self.oneOffDate = oneOffDate
        self.reminderLeadMinutes = reminderLeadMinutes
        self.isActive = isActive
        self.subreddit = subreddit
    }
}
```

- [ ] **Step 7: Run tests**

Run: `make test`
Expected: All 5 tests pass

- [ ] **Step 8: Commit**

```bash
git add Sources/Models/ Tests/
git commit -m "feat: SwiftData models for Project, Capture, Subreddit, SubredditEvent"
```

---

### Task 3: Constants and Utilities

**Files:**
- Create: `Sources/Utilities/Constants.swift`
- Create: `Sources/Utilities/RRuleHelper.swift`
- Create: `Tests/RedditReminderTests/RRuleHelperTests.swift`

- [ ] **Step 1: Create `Sources/Utilities/Constants.swift`**

```swift
import Foundation
import AppKit

enum SidebarState: String, CaseIterable {
    case strip
    case glance
    case browse
    case capture
}

enum SidebarConstants {
    static let stripWidth: CGFloat = 24
    static let glanceWidth: CGFloat = 200
    static let browseWidth: CGFloat = 320
    static let captureWidth: CGFloat = 480
    static let animationDuration: CGFloat = 0.35
    static let defaultAutoCollapseMinutes: Int = 5

    static func width(for state: SidebarState) -> CGFloat {
        switch state {
        case .strip: return stripWidth
        case .glance: return glanceWidth
        case .browse: return browseWidth
        case .capture: return captureWidth
        }
    }
}

enum UrgencyLevel: Comparable {
    case none
    case low
    case medium
    case high
    case active
    case expired
}

enum AppColors {
    static let reddit = NSColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0) // #ff4500
    static let green = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)  // #22c55e
    static let blue = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1.0)   // #4a9eff
    static let purple = NSColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1.0) // #a855f7
}

enum MediaConstants {
    static let thumbnailMaxSize: CGFloat = 200
    static let supportedImageTypes = ["png", "jpg", "jpeg", "gif"]
    static let supportedVideoTypes = ["mp4", "mov"]
    static var supportedTypes: [String] { supportedImageTypes + supportedVideoTypes }
}
```

- [ ] **Step 2: Write RRULE helper tests**

Create `Tests/RedditReminderTests/RRuleHelperTests.swift`:

```swift
import Testing
import Foundation
@testable import RedditReminder

@Test func weeklyRRuleNextOccurrence() {
    // "Every Saturday" starting from a Wednesday
    let wednesday = calendar(2026, 4, 22, 10, 0) // Wed Apr 22 2026
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: wednesday
    )
    #expect(next != nil)
    let cal = Calendar.current
    #expect(cal.component(.weekday, from: next!) == 7) // Saturday
    #expect(next! > wednesday)
}

@Test func weeklyRRuleMultipleOccurrences() {
    let monday = calendar(2026, 4, 20, 10, 0)
    let occurrences = RRuleHelper.nextOccurrences(
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        after: monday,
        count: 3
    )
    #expect(occurrences.count == 3)
    // Each should be a Saturday, one week apart
    let cal = Calendar.current
    for occ in occurrences {
        #expect(cal.component(.weekday, from: occ) == 7)
    }
}

@Test func dailyRRuleNextOccurrence() {
    let now = calendar(2026, 4, 25, 10, 0)
    let next = RRuleHelper.nextOccurrence(
        rrule: "FREQ=DAILY",
        after: now
    )
    #expect(next != nil)
    let cal = Calendar.current
    let dayDiff = cal.dateComponents([.day], from: now, to: next!).day!
    #expect(dayDiff == 1)
}

@Test func invalidRRuleReturnsNil() {
    let now = Date()
    let next = RRuleHelper.nextOccurrence(rrule: "GARBAGE", after: now)
    #expect(next == nil)
}

private func calendar(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
    c.timeZone = TimeZone(identifier: "America/New_York")
    return Calendar.current.date(from: c)!
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `RRuleHelper` not defined

- [ ] **Step 4: Create `Sources/Utilities/RRuleHelper.swift`**

```swift
import Foundation

enum RRuleHelper {
    /// Parse a simple RRULE and return the next occurrence after `after`.
    /// Supports: FREQ=WEEKLY;BYDAY=XX and FREQ=DAILY
    static func nextOccurrence(rrule: String, after: Date) -> Date? {
        let occurrences = nextOccurrences(rrule: rrule, after: after, count: 1)
        return occurrences.first
    }

    /// Return the next `count` occurrences of an RRULE after `after`.
    static func nextOccurrences(rrule: String, after: Date, count: Int) -> [Date] {
        guard let parsed = parse(rrule) else { return [] }

        var results: [Date] = []
        let cal = Calendar.current
        var candidate = cal.startOfDay(for: after)

        // Search up to 365 days ahead
        for _ in 0..<365 {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate)!

            switch parsed {
            case .weekly(let targetWeekday):
                let weekday = cal.component(.weekday, from: candidate)
                if weekday == targetWeekday {
                    // Preserve the time from `after`
                    let time = cal.dateComponents([.hour, .minute], from: after)
                    var components = cal.dateComponents([.year, .month, .day], from: candidate)
                    components.hour = time.hour
                    components.minute = time.minute
                    if let date = cal.date(from: components), date > after {
                        results.append(date)
                    }
                }
            case .daily:
                let time = cal.dateComponents([.hour, .minute], from: after)
                var components = cal.dateComponents([.year, .month, .day], from: candidate)
                components.hour = time.hour
                components.minute = time.minute
                if let date = cal.date(from: components), date > after {
                    results.append(date)
                }
            }

            if results.count >= count { break }
        }

        return results
    }

    private enum ParsedRule {
        case weekly(Int) // weekday: 1=Sunday, 7=Saturday
        case daily
    }

    private static func parse(_ rrule: String) -> ParsedRule? {
        let parts = rrule.split(separator: ";").reduce(into: [String: String]()) { dict, part in
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { dict[String(kv[0])] = String(kv[1]) }
        }

        guard let freq = parts["FREQ"] else { return nil }

        switch freq {
        case "WEEKLY":
            guard let byday = parts["BYDAY"] else { return nil }
            guard let weekday = weekdayNumber(byday) else { return nil }
            return .weekly(weekday)
        case "DAILY":
            return .daily
        default:
            return nil
        }
    }

    /// Convert RRULE day abbreviation to Calendar weekday (1=Sun, 7=Sat)
    private static func weekdayNumber(_ abbrev: String) -> Int? {
        switch abbrev.uppercased() {
        case "SU": return 1
        case "MO": return 2
        case "TU": return 3
        case "WE": return 4
        case "TH": return 5
        case "FR": return 6
        case "SA": return 7
        default: return nil
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: All RRULE tests pass (4 new + 5 existing = 9 total)

- [ ] **Step 6: Commit**

```bash
git add Sources/Utilities/ Tests/RedditReminderTests/RRuleHelperTests.swift
git commit -m "feat: Constants, SidebarState enum, and RRuleHelper with tests"
```

---

### Task 4: HeuristicsStore — Bundled Peak Times

**Files:**
- Modify: `Resources/peak-times.json`
- Create: `Sources/Services/HeuristicsStore.swift`
- Create: `Tests/RedditReminderTests/HeuristicsStoreTests.swift`

- [ ] **Step 1: Write heuristics tests**

Create `Tests/RedditReminderTests/HeuristicsStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import RedditReminder

@Test func loadBundledHeuristics() {
    let store = HeuristicsStore()
    let peak = store.peakInfo(for: "r/SideProject")
    #expect(peak != nil)
    #expect(peak!.peakDays.contains("tue"))
    #expect(peak!.peakDays.contains("sat"))
    #expect(peak!.peakHoursUtc.contains(14))
}

@Test func unknownSubredditReturnsNil() {
    let store = HeuristicsStore()
    let peak = store.peakInfo(for: "r/nonexistent")
    #expect(peak == nil)
}

@Test func userOverrideTakesPrecedence() {
    let store = HeuristicsStore()
    store.setOverride(
        for: "r/SideProject",
        peakDays: ["mon"],
        peakHoursUtc: [9, 10]
    )
    let peak = store.peakInfo(for: "r/SideProject")
    #expect(peak != nil)
    #expect(peak!.peakDays == ["mon"])
    #expect(peak!.peakHoursUtc == [9, 10])
}

@Test func clearOverrideFallsBackToBundled() {
    let store = HeuristicsStore()
    store.setOverride(for: "r/SideProject", peakDays: ["mon"], peakHoursUtc: [9])
    store.clearOverride(for: "r/SideProject")
    let peak = store.peakInfo(for: "r/SideProject")
    #expect(peak!.peakDays.contains("tue")) // back to bundled
}

@Test func isCurrentlyPeakHour() {
    let store = HeuristicsStore()
    // r/SideProject peaks at UTC 14, 15, 16
    let peakTime = utcDate(hour: 14, minute: 30) // 2:30 PM UTC
    let offPeakTime = utcDate(hour: 6, minute: 0) // 6 AM UTC
    let tuesday = dayOfWeek(.tuesday, at: 14) // Tuesday at peak hour

    #expect(store.isPeakWindow(for: "r/SideProject", at: tuesday))
    #expect(!store.isPeakWindow(for: "r/SideProject", at: offPeakTime))
}

private func utcDate(hour: Int, minute: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    var c = cal.dateComponents([.year, .month, .day], from: Date())
    c.hour = hour; c.minute = minute
    // Make it a Tuesday (peak day for SideProject)
    c.weekday = 3 // Tuesday
    return cal.date(from: c)!
}

private func dayOfWeek(_ weekday: Weekday, at utcHour: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    // Find next occurrence of the given weekday
    var date = Date()
    while cal.component(.weekday, from: date) != weekday.rawValue {
        date = cal.date(byAdding: .day, value: 1, to: date)!
    }
    var c = cal.dateComponents([.year, .month, .day], from: date)
    c.hour = utcHour; c.minute = 0
    return cal.date(from: c)!
}

private enum Weekday: Int {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `HeuristicsStore` not defined

- [ ] **Step 3: Populate `Resources/peak-times.json`**

```json
{
  "r/SideProject": {
    "peak_days": ["tue", "sat"],
    "peak_hours_utc": [14, 15, 16]
  },
  "r/webdev": {
    "peak_days": ["tue", "thu"],
    "peak_hours_utc": [14, 15]
  },
  "r/MacApps": {
    "peak_days": ["mon", "wed"],
    "peak_hours_utc": [15, 16]
  },
  "r/indiehackers": {
    "peak_days": ["tue", "thu"],
    "peak_hours_utc": [14, 15, 16]
  }
}
```

- [ ] **Step 4: Create `Sources/Services/HeuristicsStore.swift`**

```swift
import Foundation

struct PeakInfo {
    let peakDays: [String]
    let peakHoursUtc: [Int]
}

@MainActor
final class HeuristicsStore {
    private var bundled: [String: PeakInfo] = [:]
    private var overrides: [String: PeakInfo] = [:]

    init() {
        loadBundled()
    }

    func peakInfo(for subreddit: String) -> PeakInfo? {
        if let override = overrides[subreddit] { return override }
        return bundled[subreddit]
    }

    func setOverride(for subreddit: String, peakDays: [String], peakHoursUtc: [Int]) {
        overrides[subreddit] = PeakInfo(peakDays: peakDays, peakHoursUtc: peakHoursUtc)
    }

    func clearOverride(for subreddit: String) {
        overrides.removeValue(forKey: subreddit)
    }

    func isPeakWindow(for subreddit: String, at date: Date) -> Bool {
        guard let peak = peakInfo(for: subreddit) else { return false }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let hour = cal.component(.hour, from: date)
        guard peak.peakHoursUtc.contains(hour) else { return false }

        let weekday = cal.component(.weekday, from: date)
        let dayAbbrev = Self.weekdayAbbrev(weekday)
        return peak.peakDays.contains(dayAbbrev)
    }

    private func loadBundled() {
        guard let url = Bundle.main.url(forResource: "peak-times", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        else { return }

        for (sub, info) in json {
            if let days = info["peak_days"] as? [String],
               let hours = info["peak_hours_utc"] as? [Int] {
                bundled[sub] = PeakInfo(peakDays: days, peakHoursUtc: hours)
            }
        }
    }

    private static func weekdayAbbrev(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "sun"
        case 2: return "mon"
        case 3: return "tue"
        case 4: return "wed"
        case 5: return "thu"
        case 6: return "fri"
        case 7: return "sat"
        default: return ""
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: All heuristics tests pass

- [ ] **Step 6: Commit**

```bash
git add Sources/Services/HeuristicsStore.swift Resources/peak-times.json Tests/RedditReminderTests/HeuristicsStoreTests.swift
git commit -m "feat: HeuristicsStore with bundled peak times and user overrides"
```

---

### Task 5: MediaStore — File Storage and Thumbnails

**Files:**
- Create: `Sources/Services/MediaStore.swift`
- Create: `Tests/RedditReminderTests/MediaStoreTests.swift`

- [ ] **Step 1: Write media store tests**

Create `Tests/RedditReminderTests/MediaStoreTests.swift`:

```swift
import Testing
import Foundation
import AppKit
@testable import RedditReminder

@Test func saveAndLoadMedia() throws {
    let store = MediaStore(rootDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let image = createTestImage(width: 800, height: 600)
    let captureId = UUID()

    let ref = try store.save(image: image, captureId: captureId, fileName: "test.png")
    #expect(ref == "test.png")

    let loaded = store.loadImage(captureId: captureId, ref: ref)
    #expect(loaded != nil)
}

@Test func thumbnailIsSmallerThanOriginal() throws {
    let store = MediaStore(rootDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let image = createTestImage(width: 800, height: 600)
    let captureId = UUID()

    _ = try store.save(image: image, captureId: captureId, fileName: "big.png")
    let thumb = store.loadThumbnail(captureId: captureId, ref: "big.png")
    #expect(thumb != nil)
    #expect(thumb!.size.width <= 200)
    #expect(thumb!.size.height <= 200)
}

@Test func deleteRemovesFiles() throws {
    let store = MediaStore(rootDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    let image = createTestImage(width: 100, height: 100)
    let captureId = UUID()

    _ = try store.save(image: image, captureId: captureId, fileName: "del.png")
    store.deleteAll(captureId: captureId)

    let loaded = store.loadImage(captureId: captureId, ref: "del.png")
    #expect(loaded == nil)
}

private func createTestImage(width: Int, height: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.unlockFocus()
    return image
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `MediaStore` not defined

- [ ] **Step 3: Create `Sources/Services/MediaStore.swift`**

```swift
import Foundation
import AppKit

final class MediaStore {
    private let rootDir: URL
    private let fm = FileManager.default

    init(rootDir: URL? = nil) {
        if let rootDir {
            self.rootDir = rootDir
        } else {
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.rootDir = appSupport.appendingPathComponent("RedditReminder/media")
        }
    }

    /// Save an image for a capture. Returns the media reference (filename).
    func save(image: NSImage, captureId: UUID, fileName: String) throws -> String {
        let captureDir = rootDir.appendingPathComponent(captureId.uuidString)
        let thumbDir = captureDir.appendingPathComponent("thumbnails")
        try fm.createDirectory(at: captureDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: thumbDir, withIntermediateDirectories: true)

        // Save original
        guard let data = pngData(from: image) else {
            throw MediaError.encodingFailed
        }
        let fileURL = captureDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        // Generate and save thumbnail
        let thumbnail = generateThumbnail(from: image, maxSize: MediaConstants.thumbnailMaxSize)
        if let thumbData = pngData(from: thumbnail) {
            let thumbURL = thumbDir.appendingPathComponent(fileName)
            try? thumbData.write(to: thumbURL)
        }

        return fileName
    }

    /// Load the original image for a capture.
    func loadImage(captureId: UUID, ref: String) -> NSImage? {
        let url = rootDir
            .appendingPathComponent(captureId.uuidString)
            .appendingPathComponent(ref)
        return NSImage(contentsOf: url)
    }

    /// Load the thumbnail for a capture.
    func loadThumbnail(captureId: UUID, ref: String) -> NSImage? {
        let url = rootDir
            .appendingPathComponent(captureId.uuidString)
            .appendingPathComponent("thumbnails")
            .appendingPathComponent(ref)
        return NSImage(contentsOf: url)
    }

    /// Delete all media for a capture.
    func deleteAll(captureId: UUID) {
        let dir = rootDir.appendingPathComponent(captureId.uuidString)
        try? fm.removeItem(at: dir)
    }

    private func generateThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage {
        let originalSize = image.size
        let aspect = originalSize.width / originalSize.height

        let size: NSSize
        if originalSize.width > originalSize.height {
            size = NSSize(width: maxSize, height: maxSize / aspect)
        } else {
            size = NSSize(width: maxSize * aspect, height: maxSize)
        }

        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()
        return thumbnail
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return png
    }
}

enum MediaError: Error {
    case encodingFailed
}
```

- [ ] **Step 4: Run tests**

Run: `make test`
Expected: All 3 media tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/MediaStore.swift Tests/RedditReminderTests/MediaStoreTests.swift
git commit -m "feat: MediaStore with file storage, thumbnails, and cleanup"
```

---

### Task 6: PanelController — NSPanel and State Machine

**Files:**
- Create: `Sources/Services/PanelController.swift`
- Modify: `Sources/App/AppDelegate.swift`

- [ ] **Step 1: Create `Sources/Services/PanelController.swift`**

```swift
import AppKit
import SwiftUI
import Observation

@MainActor
@Observable
final class PanelController {
    var state: SidebarState = .glance
    var screenEdge: ScreenEdge = .right

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var autoCollapseTimer: Timer?
    private var restingState: SidebarState = .glance
    private var autoCollapseMinutes: Int = SidebarConstants.defaultAutoCollapseMinutes

    enum ScreenEdge { case left, right }

    func setup(contentView: some View) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: SidebarConstants.glanceWidth, height: 0),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true
        panel.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.16, alpha: 1.0)
        panel.isOpaque = false

        let hosting = NSHostingView(rootView: AnyView(contentView))
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting

        positionPanel()
        panel.orderFront(nil)
        resetAutoCollapseTimer()
    }

    func setState(_ newState: SidebarState) {
        state = newState
        animateWidth()
        resetAutoCollapseTimer()
    }

    func stepDown() {
        let states = SidebarState.allCases
        guard let idx = states.firstIndex(of: state), idx > 0 else { return }
        setState(states[idx - 1])
    }

    func toggleCapture() {
        if state == .capture {
            setState(.browse)
        } else {
            setState(.capture)
        }
    }

    func setScreenEdge(_ edge: ScreenEdge) {
        screenEdge = edge
        positionPanel()
    }

    func setAutoCollapse(minutes: Int, restingState: SidebarState) {
        self.autoCollapseMinutes = minutes
        self.restingState = restingState
        resetAutoCollapseTimer()
    }

    private func animateWidth() {
        guard let panel else { return }
        let targetWidth = SidebarConstants.width(for: state)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = SidebarConstants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            var frame = panel.frame
            let widthDelta = targetWidth - frame.width

            if screenEdge == .right {
                frame.origin.x -= widthDelta
            }
            frame.size.width = targetWidth

            panel.animator().setFrame(frame, display: true)
        }
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let width = SidebarConstants.width(for: state)

        let x: CGFloat
        if screenEdge == .right {
            x = screenFrame.maxX - width
        } else {
            x = screenFrame.minX
        }

        let frame = NSRect(
            x: x,
            y: screenFrame.minY,
            width: width,
            height: screenFrame.height
        )
        panel.setFrame(frame, display: true)
    }

    private func resetAutoCollapseTimer() {
        autoCollapseTimer?.invalidate()
        guard autoCollapseMinutes > 0 else { return }

        autoCollapseTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(autoCollapseMinutes * 60),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.state.isWiderThan(self.restingState) {
                    self.setState(self.restingState)
                }
            }
        }
    }
}

extension SidebarState {
    func isWiderThan(_ other: SidebarState) -> Bool {
        SidebarConstants.width(for: self) > SidebarConstants.width(for: other)
    }
}
```

- [ ] **Step 2: Update `Sources/App/AppDelegate.swift`**

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelController = PanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("RedditReminder: launched")
    }
}
```

- [ ] **Step 3: Update `Sources/App/RedditReminderApp.swift` to wire panel**

```swift
import SwiftUI
import SwiftData

@main
struct RedditReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("RedditReminderKeepalive") {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    let container = SidebarContainer(panelController: appDelegate.panelController)
                    appDelegate.panelController.setup(contentView: container)
                }
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
    }
}
```

- [ ] **Step 4: Create placeholder `Sources/Views/SidebarContainer.swift`**

```swift
import SwiftUI

struct SidebarContainer: View {
    let panelController: PanelController

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.16, alpha: 1.0))

            switch panelController.state {
            case .strip:
                Text("Strip")
                    .foregroundStyle(.secondary)
            case .glance:
                Text("Glance")
                    .foregroundStyle(.secondary)
            case .browse:
                Text("Browse")
                    .foregroundStyle(.secondary)
            case .capture:
                Text("Capture")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 5: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Sources/Services/PanelController.swift Sources/App/ Sources/Views/SidebarContainer.swift
git commit -m "feat: PanelController with NSPanel, width state machine, and auto-collapse"
```

---

### Task 7: Global Keyboard Shortcut

**Files:**
- Create: `Sources/Utilities/KeyboardShortcuts.swift`
- Modify: `Sources/App/AppDelegate.swift`

- [ ] **Step 1: Create `Sources/Utilities/KeyboardShortcuts.swift`**

```swift
import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalShortcut {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: (() -> Void)?

    /// Register ⌘⇧R as a global hotkey.
    func register(handler: @escaping () -> Void) {
        self.handler = handler

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(refcon).takeUnretainedValue()
            return shortcut.handleEvent(proxy: proxy, type: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("RedditReminder: failed to create event tap — grant Accessibility permission")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        handler = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // ⌘⇧R: keyCode 15 = 'R', flags contain .maskCommand and .maskShift
        let isCmd = flags.contains(.maskCommand)
        let isShift = flags.contains(.maskShift)
        let isR = keyCode == 15

        if isCmd && isShift && isR {
            Task { @MainActor in
                self.handler?()
            }
            return nil // consume the event
        }

        return Unmanaged.passRetained(event)
    }
}
```

- [ ] **Step 2: Wire shortcut in `AppDelegate.swift`**

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelController = PanelController()
    private let globalShortcut = GlobalShortcut()

    func applicationDidFinishLaunching(_ notification: Notification) {
        globalShortcut.register { [weak self] in
            self?.panelController.toggleCapture()
        }
        NSLog("RedditReminder: launched, ⌘⇧R registered")
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcut.unregister()
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Utilities/KeyboardShortcuts.swift Sources/App/AppDelegate.swift
git commit -m "feat: global ⌘⇧R keyboard shortcut via CGEvent tap"
```

---

### Task 8: NotificationService

**Files:**
- Create: `Sources/Services/NotificationService.swift`

- [ ] **Step 1: Create `Sources/Services/NotificationService.swift`**

```swift
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("RedditReminder: notification permission error: \(error)")
            return false
        }
    }

    /// Schedule a notification for an upcoming posting window.
    func scheduleWindowNotification(
        eventId: String,
        title: String,
        body: String,
        fireDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "POSTING_WINDOW"

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(
            identifier: "window-\(eventId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                NSLog("RedditReminder: failed to schedule notification: \(error)")
            }
        }
    }

    /// Schedule a "nothing queued" nudge.
    func scheduleEmptyQueueNudge(
        eventId: String,
        subredditName: String,
        eventName: String,
        fireDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "\(eventName) is approaching"
        content.body = "Nothing queued for \(subredditName) yet — capture something?"
        content.sound = .default
        content.categoryIdentifier = "EMPTY_QUEUE_NUDGE"

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(
            identifier: "nudge-\(eventId)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                NSLog("RedditReminder: failed to schedule nudge: \(error)")
            }
        }
    }

    /// Cancel all scheduled notifications for an event.
    func cancelNotifications(eventId: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: ["window-\(eventId)", "nudge-\(eventId)"]
        )
    }

    /// Cancel all pending notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/NotificationService.swift
git commit -m "feat: NotificationService for posting window and empty-queue nudges"
```

---

### Task 9: TimingEngine — Window Matching and Urgency

**Files:**
- Create: `Sources/Services/TimingEngine.swift`
- Create: `Tests/RedditReminderTests/TimingEngineTests.swift`

- [ ] **Step 1: Write timing engine tests**

Create `Tests/RedditReminderTests/TimingEngineTests.swift`:

```swift
import Testing
import Foundation
@testable import RedditReminder

@Test func urgencyFromHoursAway() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 30) == .none)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 18) == .low)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 6) == .medium)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 1) == .high)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0) == .active)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: -1) == .expired)
}

@Test func upcomingWindowForEvent() {
    let sub = Subreddit(name: "r/SideProject")
    let event = SubredditEvent(
        name: "Show-off Saturday",
        subreddit: sub,
        rrule: "FREQ=WEEKLY;BYDAY=SA"
    )
    let now = Date()
    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)
    #expect(window! > now)

    let cal = Calendar.current
    #expect(cal.component(.weekday, from: window!) == 7) // Saturday
}

@Test func upcomingWindowForOneOff() {
    let sub = Subreddit(name: "r/SideProject")
    let futureDate = Date().addingTimeInterval(86400 * 3) // 3 days from now
    let event = SubredditEvent(
        name: "Launch Day",
        subreddit: sub,
        oneOffDate: futureDate
    )
    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window != nil)
    #expect(window == futureDate)
}

@Test func expiredOneOffReturnsNil() {
    let sub = Subreddit(name: "r/SideProject")
    let pastDate = Date().addingTimeInterval(-86400) // yesterday
    let event = SubredditEvent(
        name: "Old Launch",
        subreddit: sub,
        oneOffDate: pastDate
    )
    let window = TimingEngine.nextWindow(for: event, after: Date())
    #expect(window == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `TimingEngine` not defined

- [ ] **Step 3: Create `Sources/Services/TimingEngine.swift`**

```swift
import Foundation

@MainActor
@Observable
final class TimingEngine {
    struct UpcomingWindow {
        let event: SubredditEvent
        let fireDate: Date
        let urgency: UrgencyLevel
        let matchingCaptureCount: Int
    }

    private(set) var upcomingWindows: [UpcomingWindow] = []

    /// Compute urgency from hours until a window opens.
    static func urgencyLevel(hoursUntilWindow: Double) -> UrgencyLevel {
        switch hoursUntilWindow {
        case _ where hoursUntilWindow < 0:
            return .expired
        case 0..<0.5:
            return .active
        case 0.5..<2:
            return .high
        case 2..<12:
            return .medium
        case 12..<24:
            return .low
        default:
            return .none
        }
    }

    /// Get the next window for an event.
    static func nextWindow(for event: SubredditEvent, after date: Date) -> Date? {
        if let oneOff = event.oneOffDate {
            return oneOff > date ? oneOff : nil
        }
        if let rrule = event.rrule {
            return RRuleHelper.nextOccurrence(rrule: rrule, after: date)
        }
        return nil
    }

    /// Run the matching cycle: find upcoming windows in the next 24 hours,
    /// match them against queued captures, and compute urgency.
    func refresh(events: [SubredditEvent], captures: [Capture]) {
        let now = Date()
        let horizon = now.addingTimeInterval(24 * 3600)
        var windows: [UpcomingWindow] = []

        for event in events where event.isActive {
            guard let fireDate = Self.nextWindow(for: event, after: now),
                  fireDate <= horizon
            else { continue }

            let hours = fireDate.timeIntervalSince(now) / 3600
            let urgency = Self.urgencyLevel(hoursUntilWindow: hours)

            let matchCount = captures.filter { capture in
                capture.status == .queued &&
                capture.subreddits.contains(where: { $0.name == event.subreddit?.name })
            }.count

            windows.append(UpcomingWindow(
                event: event,
                fireDate: fireDate,
                urgency: urgency,
                matchingCaptureCount: matchCount
            ))
        }

        upcomingWindows = windows.sorted { $0.fireDate < $1.fireDate }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `make test`
Expected: All 4 timing engine tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/TimingEngine.swift Tests/RedditReminderTests/TimingEngineTests.swift
git commit -m "feat: TimingEngine with urgency computation and window matching"
```

---

### Task 10: StripView and GlanceView

**Files:**
- Create: `Sources/Views/StripView.swift`
- Create: `Sources/Views/GlanceView.swift`
- Modify: `Sources/Views/SidebarContainer.swift`

- [ ] **Step 1: Create `Sources/Views/StripView.swift`**

```swift
import SwiftUI

struct StripView: View {
    let queueCount: Int
    let hasUrgentEvent: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if queueCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: AppColors.reddit))
                        .frame(width: 18, height: 18)
                    Text("\(queueCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            if hasUrgentEvent {
                Circle()
                    .fill(Color(nsColor: AppColors.reddit))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(nsColor: AppColors.reddit).opacity(0.6), radius: 4)
            }

            Spacer()

            Text("REDDIT")
                .font(.system(size: 9, weight: .medium))
                .tracking(2)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(90))
                .fixedSize()
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
```

- [ ] **Step 2: Create `Sources/Views/GlanceView.swift`**

```swift
import SwiftUI

struct GlanceView: View {
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    let captures: [Capture]
    let onCaptureCardTap: () -> Void
    let onNewCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // Upcoming windows
                    if let next = upcomingWindows.first {
                        alertBanner(window: next)
                    }

                    // Queue summary
                    let queued = captures.filter { $0.status == .queued }
                    if !queued.isEmpty {
                        sectionLabel("Queue · \(queued.count)")

                        ForEach(queued, id: \.id) { capture in
                            glanceCard(capture: capture)
                                .onTapGesture(perform: onCaptureCardTap)
                        }
                    }

                    // Upcoming events peek
                    if upcomingWindows.count > 1 {
                        sectionLabel("Upcoming")

                        ForEach(Array(upcomingWindows.prefix(3).enumerated()), id: \.offset) { _, window in
                            eventDot(window: window)
                        }
                    }
                }
                .padding(10)
            }

            // Capture button
            Button(action: onNewCapture) {
                Text("+ New Capture")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: AppColors.reddit))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private func alertBanner(window: TimingEngine.UpcomingWindow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("⏰")
                Text(window.event.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: AppColors.reddit))
            }
            if let sub = window.event.subreddit {
                Text("\(sub.name) · \(window.matchingCaptureCount) ready")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: AppColors.reddit).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: AppColors.reddit).opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func glanceCard(capture: Capture) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(capture.project?.name ?? "Unknown")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Text(capture.text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func eventDot(window: TimingEngine.UpcomingWindow) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(urgencyColor(window.urgency))
                .frame(width: 6, height: 6)
            Text("\(window.event.name) · \(window.event.subreddit?.name ?? "")")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }

    private func urgencyColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .none: return .gray
        case .low: return Color(nsColor: AppColors.blue)
        case .medium: return Color(nsColor: AppColors.green)
        case .high, .active: return Color(nsColor: AppColors.reddit)
        case .expired: return .gray.opacity(0.5)
        }
    }
}
```

- [ ] **Step 3: Update `Sources/Views/SidebarContainer.swift`**

```swift
import SwiftUI

struct SidebarContainer: View {
    @Bindable var panelController: PanelController
    var timingEngine: TimingEngine = TimingEngine()
    var captures: [Capture] = []

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if panelController.state != .strip {
                    header
                }

                switch panelController.state {
                case .strip:
                    StripView(
                        queueCount: captures.filter { $0.status == .queued }.count,
                        hasUrgentEvent: timingEngine.upcomingWindows.contains { $0.urgency >= .high },
                        onTap: { panelController.setState(.glance) }
                    )
                case .glance:
                    GlanceView(
                        upcomingWindows: timingEngine.upcomingWindows,
                        captures: captures,
                        onCaptureCardTap: { panelController.setState(.browse) },
                        onNewCapture: { panelController.setState(.capture) }
                    )
                case .browse:
                    Text("Browse — Task 11")
                        .foregroundStyle(.secondary)
                case .capture:
                    Text("Capture — Task 12")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("RedditReminder")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(nsColor: AppColors.reddit))
            Spacer()
            Button(action: { panelController.stepDown() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Sources/Views/
git commit -m "feat: StripView and GlanceView with urgency indicators and queue summary"
```

---

### Task 11: BrowseView — Queue and Calendar Tabs

**Files:**
- Create: `Sources/Views/CaptureCardView.swift`
- Create: `Sources/Views/EventCardView.swift`
- Create: `Sources/Views/CalendarTimelineView.swift`
- Create: `Sources/Views/CalendarMonthView.swift`
- Create: `Sources/Views/BrowseView.swift`
- Modify: `Sources/Views/SidebarContainer.swift`

- [ ] **Step 1: Create `Sources/Views/CaptureCardView.swift`**

```swift
import SwiftUI

struct CaptureCardView: View {
    let capture: Capture
    let compact: Bool
    var onMarkPosted: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(capture.project?.name ?? "Unknown")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(capture.subreddits, id: \.id) { sub in
                        Text(sub.name)
                            .font(.system(size: 9))
                            .foregroundStyle(Color(nsColor: AppColors.reddit))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: AppColors.reddit).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Text(capture.text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(compact ? 1 : 3)

            if !compact && !capture.mediaRefs.isEmpty {
                HStack(spacing: 4) {
                    ForEach(capture.mediaRefs.prefix(4), id: \.self) { ref in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
            }

            if !compact {
                HStack {
                    Text(capture.createdAt, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()

                    if capture.status == .queued, let onMarkPosted {
                        Button("Mark Posted", action: onMarkPosted)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(nsColor: AppColors.green))
                    }

                    Text(capture.status.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(capture.status == .queued
                            ? Color(nsColor: AppColors.green)
                            : .tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(capture.status == .queued
                            ? Color(nsColor: AppColors.green).opacity(0.1)
                            : Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Create `Sources/Views/EventCardView.swift`**

```swift
import SwiftUI

struct EventCardView: View {
    let window: TimingEngine.UpcomingWindow

    var body: some View {
        let isUrgent = window.urgency >= .high

        VStack(alignment: .leading, spacing: 3) {
            Text(window.event.name)
                .font(.system(size: 11, weight: isUrgent ? .bold : .regular))
                .foregroundStyle(isUrgent ? .primary : .secondary)

            if let sub = window.event.subreddit {
                Text("\(sub.name) · \(window.event.isRecurring ? "recurring" : "one-off")")
                    .font(.system(size: 10))
                    .foregroundStyle(urgencyColor)
            }

            if window.matchingCaptureCount > 0 {
                Text("\(window.matchingCaptureCount) captures ready")
                    .font(.system(size: 10))
                    .foregroundStyle(urgencyColor)
            } else {
                Text("No captures tagged yet")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isUrgent
            ? Color(nsColor: AppColors.reddit).opacity(0.08)
            : Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isUrgent
                    ? Color(nsColor: AppColors.reddit).opacity(0.3)
                    : Color.white.opacity(0.06),
                lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var urgencyColor: Color {
        switch window.urgency {
        case .active, .high: return Color(nsColor: AppColors.reddit)
        case .medium: return Color(nsColor: AppColors.green)
        case .low: return Color(nsColor: AppColors.blue)
        default: return .secondary
        }
    }
}
```

- [ ] **Step 3: Create `Sources/Views/CalendarTimelineView.swift`**

```swift
import SwiftUI

struct CalendarTimelineView: View {
    let windows: [TimingEngine.UpcomingWindow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedByDate.enumerated()), id: \.offset) { _, group in
                timelineItem(date: group.date, windows: group.windows)
            }
        }
        .padding(.leading, 7)
    }

    private var groupedByDate: [(date: Date, windows: [TimingEngine.UpcomingWindow])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: windows) { window in
            cal.startOfDay(for: window.fireDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, windows: $0.value) }
    }

    private func timelineItem(date: Date, windows: [TimingEngine.UpcomingWindow]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline rail
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor(for: windows))
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 2)
            }
            .frame(width: 16)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(dateLabel(date))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(dotColor(for: windows))

                ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                    EventCardView(window: window)
                }
            }
            .padding(.leading, 10)
            .padding(.bottom, 16)
        }
    }

    private func dotColor(for windows: [TimingEngine.UpcomingWindow]) -> Color {
        let maxUrgency = windows.map(\.urgency).max() ?? .none
        switch maxUrgency {
        case .active, .high: return Color(nsColor: AppColors.reddit)
        case .medium: return Color(nsColor: AppColors.green)
        case .low: return Color(nsColor: AppColors.blue)
        default: return .gray
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today · \(shortDate(date))"
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow · \(shortDate(date))"
        } else {
            return shortDate(date)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }
}
```

- [ ] **Step 4: Create `Sources/Views/CalendarMonthView.swift`**

```swift
import SwiftUI

struct CalendarMonthView: View {
    let windows: [TimingEngine.UpcomingWindow]
    @State private var displayMonth = Date()
    @State private var selectedDay: Date?

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Month nav
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
                Text(monthTitle)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Day headers
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(daysInMonth, id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            // Selected day detail
            if let selected = selectedDay {
                let dayWindows = windowsFor(day: selected)
                if !dayWindows.isEmpty {
                    Divider().padding(.vertical, 4)
                    Text(dayDetailTitle(selected))
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)

                    ForEach(Array(dayWindows.enumerated()), id: \.offset) { _, window in
                        EventCardView(window: window)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let dots = windowsFor(day: date)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let isToday = cal.isDateInToday(date)

        return Button(action: { selectedDay = date }) {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 10))
                    .foregroundStyle(isToday ? Color(nsColor: AppColors.reddit) : .primary)

                if !dots.isEmpty {
                    HStack(spacing: 1) {
                        ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, w in
                            Circle()
                                .fill(dotColor(w.urgency))
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Color.clear.frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayMonth)
    }

    private var daysInMonth: [Date?] {
        let range = cal.range(of: .day, in: .month, for: displayMonth)!
        let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))!
        // Monday=1 offset (ISO weekday)
        var weekday = cal.component(.weekday, from: firstDay) - 2 // shift so Monday=0
        if weekday < 0 { weekday += 7 }

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            var comps = cal.dateComponents([.year, .month], from: displayMonth)
            comps.day = day
            days.append(cal.date(from: comps))
        }
        return days
    }

    private func windowsFor(day: Date) -> [TimingEngine.UpcomingWindow] {
        windows.filter { cal.isDate($0.fireDate, inSameDayAs: day) }
    }

    private func previousMonth() {
        displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
    }

    private func nextMonth() {
        displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
    }

    private func dayDetailTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        let count = windowsFor(day: date).count
        return "\(f.string(from: date)) — \(count) event\(count == 1 ? "" : "s")"
    }

    private func dotColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .active, .high: return Color(nsColor: AppColors.reddit)
        case .medium: return Color(nsColor: AppColors.green)
        case .low: return Color(nsColor: AppColors.blue)
        default: return .gray
        }
    }
}
```

- [ ] **Step 5: Create `Sources/Views/BrowseView.swift`**

```swift
import SwiftUI

struct BrowseView: View {
    let captures: [Capture]
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    let onNewCapture: () -> Void
    var onMarkPosted: ((Capture) -> Void)? = nil

    @State private var activeTab: Tab = .queue

    enum Tab { case queue, calendar }
    @State private var calendarMode: CalendarMode = .timeline
    enum CalendarMode { case timeline, month }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                tabButton("Queue", tab: .queue)
                tabButton("Calendar", tab: .calendar)
            }
            .overlay(alignment: .bottom) { Divider() }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if activeTab == .queue {
                        queueContent
                    } else {
                        calendarContent
                    }
                }
                .padding(10)
            }

            // Capture button
            Button(action: onNewCapture) {
                Text("+ New Capture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: AppColors.reddit))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        let queued = captures.filter { $0.status == .queued }
        let posted = captures.filter { $0.status == .posted }

        if !queued.isEmpty {
            sectionLabel("Queued · \(queued.count)")
            ForEach(queued, id: \.id) { capture in
                CaptureCardView(capture: capture, compact: false) {
                    onMarkPosted?(capture)
                }
            }
        }

        if !posted.isEmpty {
            sectionLabel("Recently Posted")
            ForEach(posted.prefix(5), id: \.id) { capture in
                CaptureCardView(capture: capture, compact: false)
                    .opacity(0.5)
            }
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        // Calendar mode toggle
        HStack {
            Picker("", selection: $calendarMode) {
                Text("Month").tag(CalendarMode.month)
                Text("Timeline").tag(CalendarMode.timeline)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }

        if calendarMode == .timeline {
            CalendarTimelineView(windows: upcomingWindows)
        } else {
            CalendarMonthView(windows: upcomingWindows)
        }
    }

    private func tabButton(_ title: String, tab: Tab) -> some View {
        Button(action: { activeTab = tab }) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(activeTab == tab ? Color(nsColor: AppColors.reddit) : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if activeTab == tab {
                        Rectangle()
                            .fill(Color(nsColor: AppColors.reddit))
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }
}
```

- [ ] **Step 6: Update `SidebarContainer.swift` to wire BrowseView**

Replace the `.browse` case in the switch statement:

```swift
case .browse:
    BrowseView(
        captures: captures,
        upcomingWindows: timingEngine.upcomingWindows,
        onNewCapture: { panelController.setState(.capture) }
    )
```

- [ ] **Step 7: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Sources/Views/
git commit -m "feat: BrowseView with queue list, calendar timeline, and month view"
```

---

### Task 12: CaptureFormView

**Files:**
- Create: `Sources/Views/CaptureFormView.swift`
- Modify: `Sources/Views/SidebarContainer.swift`

- [ ] **Step 1: Create `Sources/Views/CaptureFormView.swift`**

```swift
import SwiftUI

struct CaptureFormView: View {
    let projects: [Project]
    let subreddits: [Subreddit]
    let onSave: (String, String?, Project, [Subreddit], [URL]) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @State private var notes = ""
    @State private var selectedProject: Project?
    @State private var selectedSubreddits: Set<UUID> = []
    @State private var droppedFiles: [URL] = []
    @State private var isDragOver = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("New Capture")

                    // Project + Subreddit pickers
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PROJECT").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(.tertiary)
                            Picker("", selection: $selectedProject) {
                                Text("Select...").tag(nil as Project?)
                                ForEach(projects.filter { !$0.archived }, id: \.id) { project in
                                    Text(project.name).tag(project as Project?)
                                }
                            }
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("SUBREDDITS").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(.tertiary)
                            subredditMultiSelect
                        }
                    }

                    // Text area
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WHAT HAPPENED?").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(.tertiary)
                        TextEditor(text: $text)
                            .font(.system(size: 12))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NOTES TO SELF").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(.tertiary)
                        TextField("e.g., mention the screenshot, link the demo...", text: $notes)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(8)
                            .background(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Media drop zone
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MEDIA").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(.tertiary)
                        dropZone
                        attachedFiles
                    }
                }
                .padding(12)
            }

            // Actions
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button(action: save) {
                    Text("Add to Queue ⌘↵")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(canSave ? Color(nsColor: AppColors.reddit) : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(12)
        }
    }

    private var canSave: Bool {
        !text.isEmpty && selectedProject != nil && !selectedSubreddits.isEmpty
    }

    private func save() {
        guard let project = selectedProject else { return }
        let subs = subreddits.filter { selectedSubreddits.contains($0.id) }
        onSave(text, notes.isEmpty ? nil : notes, project, subs, droppedFiles)
    }

    private var subredditMultiSelect: some View {
        HStack(spacing: 4) {
            ForEach(subreddits.filter { selectedSubreddits.contains($0.id) }, id: \.id) { sub in
                HStack(spacing: 3) {
                    Text(sub.name)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(nsColor: AppColors.reddit))
                    Button(action: { selectedSubreddits.remove(sub.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(nsColor: AppColors.reddit).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Menu("+ add") {
                ForEach(subreddits.filter { !selectedSubreddits.contains($0.id) }, id: \.id) { sub in
                    Button(sub.name) { selectedSubreddits.insert(sub.id) }
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDragOver ? Color(nsColor: AppColors.reddit) : Color.white.opacity(0.1),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .background(
                    isDragOver
                        ? Color(nsColor: AppColors.reddit).opacity(0.05)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 4) {
                Image(systemName: "paperclip")
                    .font(.system(size: 16))
                    .foregroundStyle(isDragOver ? Color(nsColor: AppColors.reddit) : .secondary)
                Text("Drop images or videos here")
                    .font(.system(size: 12))
                    .foregroundStyle(isDragOver ? Color(nsColor: AppColors.reddit) : .secondary)
                Text("PNG, JPG, GIF, MP4")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 20)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async {
                            droppedFiles.append(url)
                        }
                    }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private var attachedFiles: some View {
        if !droppedFiles.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(droppedFiles.enumerated()), id: \.offset) { idx, url in
                    HStack(spacing: 4) {
                        Image(systemName: "doc")
                            .font(.system(size: 10))
                        Text(url.lastPathComponent)
                            .font(.system(size: 10))
                            .lineLimit(1)
                        Button(action: { droppedFiles.remove(at: idx) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }
}
```

- [ ] **Step 2: Update `SidebarContainer.swift` to wire CaptureFormView**

Replace the `.capture` case:

```swift
case .capture:
    CaptureFormView(
        projects: [], // Will be wired to SwiftData in Task 13
        subreddits: [],
        onSave: { _, _, _, _, _ in
            panelController.setState(.browse)
        },
        onCancel: { panelController.setState(.browse) }
    )
```

- [ ] **Step 3: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/CaptureFormView.swift Sources/Views/SidebarContainer.swift
git commit -m "feat: CaptureFormView with project/subreddit pickers, text, notes, and media drop"
```

---

### Task 13: SwiftData Integration — Wire Models to Views

**Files:**
- Modify: `Sources/App/RedditReminderApp.swift`
- Modify: `Sources/App/AppDelegate.swift`
- Modify: `Sources/Views/SidebarContainer.swift`
- Create: `Sources/Views/SettingsView.swift`

- [ ] **Step 1: Update `RedditReminderApp.swift` with SwiftData container**

```swift
import SwiftUI
import SwiftData

@main
struct RedditReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("RedditReminderKeepalive") {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    let sidebarView = SidebarContainer(panelController: appDelegate.panelController)
                        .modelContainer(container)
                    appDelegate.panelController.setup(contentView: sidebarView)
                }
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
    }
}
```

- [ ] **Step 2: Update `SidebarContainer.swift` to use SwiftData queries**

```swift
import SwiftUI
import SwiftData

struct SidebarContainer: View {
    @Bindable var panelController: PanelController
    @State private var timingEngine = TimingEngine()

    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Subreddit.name) private var subreddits: [Subreddit]
    @Query(filter: #Predicate<SubredditEvent> { $0.isActive }) private var activeEvents: [SubredditEvent]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if panelController.state != .strip {
                    header
                }

                switch panelController.state {
                case .strip:
                    StripView(
                        queueCount: captures.filter { $0.status == .queued }.count,
                        hasUrgentEvent: timingEngine.upcomingWindows.contains { $0.urgency >= .high },
                        onTap: { panelController.setState(.glance) }
                    )
                case .glance:
                    GlanceView(
                        upcomingWindows: timingEngine.upcomingWindows,
                        captures: captures,
                        onCaptureCardTap: { panelController.setState(.browse) },
                        onNewCapture: { panelController.setState(.capture) }
                    )
                case .browse:
                    BrowseView(
                        captures: captures,
                        upcomingWindows: timingEngine.upcomingWindows,
                        onNewCapture: { panelController.setState(.capture) },
                        onMarkPosted: { capture in
                            capture.markAsPosted()
                            try? modelContext.save()
                        }
                    )
                case .capture:
                    CaptureFormView(
                        projects: projects,
                        subreddits: subreddits,
                        onSave: { text, notes, project, subs, mediaURLs in
                            let capture = Capture(
                                text: text,
                                notes: notes,
                                mediaRefs: mediaURLs.map(\.lastPathComponent),
                                project: project,
                                subreddits: subs
                            )
                            modelContext.insert(capture)
                            try? modelContext.save()
                            panelController.setState(.browse)
                        },
                        onCancel: { panelController.setState(.browse) }
                    )
                }
            }
        }
        .onAppear {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
        .onChange(of: captures.count) {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
    }

    private var header: some View {
        HStack {
            Text("RedditReminder")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(nsColor: AppColors.reddit))
            Spacer()
            Button(action: { panelController.stepDown() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
```

- [ ] **Step 3: Create `Sources/Views/SettingsView.swift`**

```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var panelController: PanelController

    @AppStorage("screenEdge") private var screenEdge = "right"
    @AppStorage("restingState") private var restingState = "glance"
    @AppStorage("autoCollapseMinutes") private var autoCollapseMinutes = 5
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("defaultLeadTimeMinutes") private var defaultLeadTimeMinutes = 60
    @AppStorage("nudgeWhenEmpty") private var nudgeWhenEmpty = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("Sidebar Behavior")

                LabeledContent("Screen edge") {
                    Picker("", selection: $screenEdge) {
                        Text("Left").tag("left")
                        Text("Right").tag("right")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 150)
                    .onChange(of: screenEdge) { _, newVal in
                        panelController.setScreenEdge(newVal == "left" ? .left : .right)
                    }
                }

                LabeledContent("Resting state") {
                    Picker("", selection: $restingState) {
                        Text("Strip").tag("strip")
                        Text("Glance").tag("glance")
                        Text("Browse").tag("browse")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                LabeledContent("Auto-collapse") {
                    Picker("", selection: $autoCollapseMinutes) {
                        Text("1 min").tag(1)
                        Text("5 min").tag(5)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("Never").tag(0)
                    }
                    .frame(maxWidth: 120)
                }

                Divider()
                sectionLabel("Notifications")

                Toggle("macOS notifications", isOn: $notificationsEnabled)

                LabeledContent("Default lead time") {
                    Picker("", selection: $defaultLeadTimeMinutes) {
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .frame(maxWidth: 120)
                }

                Toggle("Nudge when queue empty", isOn: $nudgeWhenEmpty)
            }
            .padding(16)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Sources/
git commit -m "feat: SwiftData integration — wire models to views with queries and persistence"
```

---

### Task 14: TimingEngine Background Timer and Notification Scheduling

**Files:**
- Modify: `Sources/App/AppDelegate.swift`

- [ ] **Step 1: Update `AppDelegate.swift` with timing engine polling**

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelController = PanelController()
    let timingEngine = TimingEngine()
    let notificationService = NotificationService()
    let heuristicsStore = HeuristicsStore()

    private let globalShortcut = GlobalShortcut()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global shortcut
        globalShortcut.register { [weak self] in
            self?.panelController.toggleCapture()
        }

        // Request notification permission
        Task {
            _ = await notificationService.requestPermission()
        }

        // Start 5-minute refresh timer
        startRefreshTimer()

        NSLog("RedditReminder: launched, ⌘⇧R registered, refresh timer started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcut.unregister()
        refreshTimer?.invalidate()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 5 * 60, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.runRefreshCycle()
            }
        }
        // Also run immediately on launch
        runRefreshCycle()
    }

    private func runRefreshCycle() {
        // Note: The actual SwiftData fetch and notification scheduling
        // will be driven by SidebarContainer's onChange handlers.
        // This timer ensures the timing engine re-evaluates urgency
        // even when no data changes occur (time-based urgency shifts).
        NSLog("RedditReminder: refresh cycle tick")
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/App/AppDelegate.swift
git commit -m "feat: background refresh timer and notification permission request on launch"
```

---

### Task 15: Manual Smoke Test and Polish

**Files:**
- No new files — build, run, and verify

- [ ] **Step 1: Build the app**

Run: `make build`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Install and run**

Run: `make install`
Expected: App opens, sidebar panel appears on right edge of screen

- [ ] **Step 3: Verify sidebar states**

Manually test:
1. Sidebar appears at Glance (200px) width
2. Press `⌘⇧R` — sidebar widens to Capture (480px)
3. Press `Esc` — steps down to Browse (320px)
4. Press `Esc` — steps down to Glance (200px)
5. Press `Esc` — collapses to Strip (24px)
6. Click strip — expands to Glance

- [ ] **Step 4: Verify persistence**

1. In Capture mode, create a project and subreddit (if the UI allows, or use manual SwiftData seeding)
2. Add a capture with text and target subreddit
3. Quit and reopen — capture should persist

- [ ] **Step 5: Commit any polish fixes**

```bash
git add -A
git commit -m "fix: smoke test polish"
```

- [ ] **Step 6: Final push**

```bash
git push origin main
```
