# UX Improvements & Test Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 4 UX improvements (hover-to-reveal actions, color-coded toasts, per-subreddit posting, expandable event banner) and 5 test gap closures (lifecycle integration, backup round-trip, notification permissions, timezone edges, UI workflows).

**Architecture:** All changes are additive — no refactors or breaking changes. Model changes add a new `postedSubredditIDs` field to `Capture`. View changes are localized to individual view files. Test additions are independent new test files. The delete confirmation already exists in `PopoverContentActions.swift:250-258` via `NSAlert`, so that task is skipped.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, Swift Testing framework, XCTest (UI tests)

---

## File Structure

**Modified files:**
- `Sources/Models/Capture.swift` — add `postedSubredditIDs` field and per-subreddit posting methods
- `Sources/Views/CaptureCardView.swift` — hover-to-reveal action pattern
- `Sources/Views/PopoverChromeViews.swift` — color-coded `PopoverToastView`
- `Sources/Views/PopoverContentView.swift` — change toast state from `String?` to `Toast?`
- `Sources/Views/PopoverContentActions.swift` — pass `ToastStyle` to all toast call sites
- `Sources/Views/PostHandoffView.swift` — per-subreddit posting checklist in destination section
- `Sources/Views/PostHandoffViewHelpers.swift` — existing helpers used by updated destination section (no modifications needed)
- `Sources/Views/EventBannerView.swift` — expandable disclosure with all upcoming windows
- `Sources/Services/TimingEngine.swift` — exclude partially-posted subreddits from count
- `Sources/Services/BackupTypes.swift` — add `postedSubredditIDs` to `BackupCapture`
- `Sources/Services/BackupMappers.swift` — map `postedSubredditIDs` in `BackupCapture.init(capture:)`
- `Sources/Services/BackupService.swift` — restore `postedSubredditIDs` on import
- `Sources/Utilities/PopoverTimingPresentation.swift` — include `postedSubredditIDs` in timing signature

**New test files:**
- `Tests/RedditReminderTests/CapturePerSubredditPostingTests.swift`
- `Tests/RedditReminderTests/CaptureLifecycleIntegrationTests.swift`
- `Tests/RedditReminderTests/BackupRoundTripTests.swift`
- `Tests/RedditReminderTests/NotificationSchedulerPermissionTests.swift`
- `Tests/RedditReminderTests/TimingEngineTimezoneEdgeCaseTests.swift`
- `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift`

---

### Task 1: Color-Coded Toasts

**Files:**
- Modify: `Sources/Views/PopoverChromeViews.swift:1-17`
- Modify: `Sources/Views/PopoverContentView.swift:19-20`
- Modify: `Sources/Views/PopoverContentActions.swift`

- [ ] **Step 1: Add `ToastStyle` enum and `Toast` struct to `PopoverChromeViews.swift`**

Add above the existing `PopoverToastView`:

```swift
enum ToastStyle {
    case success
    case error
}

struct Toast: Equatable {
    let message: String
    let style: ToastStyle
}
```

- [ ] **Step 2: Update `PopoverToastView` to use `Toast` and render by style**

Replace the existing `PopoverToastView` in `PopoverChromeViews.swift`:

```swift
struct PopoverToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accentColor)
            Text(toast.message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(accentColor.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 48)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var iconName: String {
        switch toast.style {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        }
    }

    private var accentColor: Color {
        switch toast.style {
        case .success: Color(red: 0.13, green: 0.77, blue: 0.37)
        case .error: Color(red: 0.94, green: 0.27, blue: 0.27)
        }
    }
}
```

- [ ] **Step 3: Update `PopoverContentView` toast state**

In `PopoverContentView.swift`, change lines 19-20:

```swift
// Old:
@State var toastMessage: String?

// New:
@State var toast: Toast?
```

Update the overlay in `body` (around line 47):

```swift
// Old:
if let message = toastMessage {
    PopoverToastView(message: message)
}

// New:
if let toast {
    PopoverToastView(toast: toast)
}
```

- [ ] **Step 4: Update `PopoverContentActions.swift` toast methods and all call sites**

Replace the `showToast` method:

```swift
func showToast(_ message: String, style: ToastStyle = .success, delay: Duration = .zero) {
    toastTask?.cancel()
    toastTask = Task {
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.2)) { toast = Toast(message: message, style: style) }
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.2)) { toast = nil }
    }
}

func showToastAfterReopen(_ message: String, style: ToastStyle = .success) {
    menuBarController.openPopover()
    showToast(message, style: style, delay: .milliseconds(300))
}
```

Update error call sites to pass `.error`:

- `copyHandoffText` — change `showToast("Copy failed")` to `showToast("Copy failed", style: .error)`
- `copyHandoffText` — change `showToast(emptyMessage)` to `showToast(emptyMessage, style: .error)`
- `markCaptureAsPosted` — change `showToastAfterReopen("Failed to mark as posted")` to `showToastAfterReopen("Failed to mark as posted", style: .error)`
- `openRedditSubmitPage` — change `showToast("No subreddit selected")` to `showToast("No subreddit selected", style: .error)` and `showToast("Could not open Reddit")` to `showToast("Could not open Reddit", style: .error)`
- `openPostedURL` — change `showToast("Could not open posted link")` to `showToast("Could not open posted link", style: .error)`
- `restoreCaptureToQueue` — change `showToastAfterReopen("Restore failed")` to `showToastAfterReopen("Restore failed", style: .error)`
- `deleteCapture` — change `showToastAfterReopen("Delete failed")` to `showToastAfterReopen("Delete failed", style: .error)`

All success call sites keep the default `.success` — no changes needed.

- [ ] **Step 5: Build and verify**

Run: `make build`
Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add Sources/Views/PopoverChromeViews.swift Sources/Views/PopoverContentView.swift Sources/Views/PopoverContentActions.swift
git commit -m "feat: color-coded toasts with green/red styling for success/error"
```

---

### Task 2: Hover-to-Reveal Capture Card Actions

**Files:**
- Modify: `Sources/Views/CaptureCardView.swift`

- [ ] **Step 1: Add hover state to `CaptureCardView`**

Add after the existing `@State` properties (there are none currently — add after line 19):

```swift
@State private var isHovered: Bool = false
```

- [ ] **Step 2: Wrap the card body in `.onHover` and make actions conditional**

Replace the `body` property (lines 21-97) with:

```swift
var body: some View {
    HStack(alignment: .top, spacing: 10) {
        Button(action: { onTap?() }) {
            captureSummary
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())

        Spacer(minLength: 0)

        HStack(spacing: 6) {
            if isHovered {
                if let onOpenHandoff {
                    hoverActionButton(
                        systemName: "paperplane",
                        label: "Post",
                        accessibilityLabel: Self.openHandoffAccessibilityLabel,
                        action: onOpenHandoff
                    )
                }

                if let onCopyText {
                    hoverActionButton(
                        systemName: "doc.on.doc",
                        label: "Copy",
                        accessibilityLabel: Self.copyTextAccessibilityLabel,
                        action: onCopyText
                    )
                }

                if let onMarkPosted {
                    hoverActionButton(
                        systemName: "checkmark.circle",
                        label: "Done",
                        accessibilityLabel: Self.markPostedAccessibilityLabel,
                        action: onMarkPosted
                    )
                }

                if let onDelete {
                    Button(action: onDelete) {
                        Label(Self.deleteAccessibilityLabel, systemImage: "trash")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 0.94, green: 0.27, blue: 0.27))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(Self.deleteAccessibilityLabel)
                    .accessibilityLabel(Self.deleteAccessibilityLabel)
                    .accessibilityIdentifier("captureCard.\(Self.deleteAccessibilityLabel.identifierSuffix)")
                }
            }

            if let dotColor = urgencyDotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .padding(.top, 6)
                    .help(UrgencyPresentation.label(for: urgency))
                    .accessibilityLabel(UrgencyPresentation.accessibilityLabel(for: urgency))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .onHover { hovering in
        isHovered = hovering
    }
    .contextMenu {
        if let onTap { Button("Edit") { onTap() } }
        if let onOpenHandoff { Button("Prepare Post") { onOpenHandoff() } }
        if let onCopyText { Button("Copy Post Text") { onCopyText() } }
        if let onOpenSubmit { Button("Open Reddit Submit Page") { onOpenSubmit() } }
        if let onMarkPosted { Button("Mark as Posted") { onMarkPosted() } }
        if onTap != nil || onOpenHandoff != nil || onCopyText != nil || onOpenSubmit != nil
            || onMarkPosted != nil
        {
            Divider()
        }
        if let onDelete { Button("Delete", role: .destructive) { onDelete() } }
    }
}
```

Note: `onOpenSubmit` is intentionally only in the context menu (not in the hover bar) to keep the hover bar compact. The "Post" handoff button is the primary action; "Open Reddit" is secondary.

- [ ] **Step 3: Add the `hoverActionButton` helper method**

Add after the existing `actionButton` method (around line 148):

```swift
private func hoverActionButton(
    systemName: String,
    label: String,
    accessibilityLabel: String,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        HStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(accessibilityLabel)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier("captureCard.\(accessibilityLabel.identifierSuffix)")
}
```

- [ ] **Step 4: Remove the old `actionButton` method**

Delete the `actionButton` method (lines 148-163 of the original file) since it's no longer used:

```swift
// DELETE this entire method:
private func actionButton(systemName: String, label: String, action: @escaping () -> Void)
    -> some View
{
    // ...
}
```

- [ ] **Step 5: Build and verify**

Run: `make build`
Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add Sources/Views/CaptureCardView.swift
git commit -m "feat: hover-to-reveal capture card actions with labeled buttons"
```

---

### Task 3: Per-Subreddit Posting Status — Model & Engine

**Files:**
- Modify: `Sources/Models/Capture.swift`
- Modify: `Sources/Services/TimingEngine.swift:56-98`
- Modify: `Sources/Utilities/PopoverTimingPresentation.swift:8-12`

- [ ] **Step 1: Write failing tests for per-subreddit posting methods**

Create `Tests/RedditReminderTests/CapturePerSubredditPostingTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import RedditReminder

@Test @MainActor func markSubredditAsPostedAddsId() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])

    capture.markSubredditAsPosted(sub1.id)

    #expect(capture.postedSubredditIDs.contains(sub1.id))
    #expect(!capture.postedSubredditIDs.contains(sub2.id))
    #expect(capture.status == .queued)
    #expect(capture.postedAt == nil)
}

@Test @MainActor func markAllSubredditsAsPostedTransitionsToPosted() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])

    capture.markSubredditAsPosted(sub1.id)
    capture.markSubredditAsPosted(sub2.id)

    #expect(capture.status == .posted)
    #expect(capture.postedAt != nil)
    #expect(capture.postedSubredditIDs.count == 2)
}

@Test @MainActor func markSubredditAsPostedIdempotent() throws {
    let sub = Subreddit(name: "r/webdev")
    let capture = Capture(text: "Draft", subreddits: [sub])

    capture.markSubredditAsPosted(sub.id)
    capture.markSubredditAsPosted(sub.id)

    #expect(capture.postedSubredditIDs.count == 1)
    #expect(capture.status == .posted)
}

@Test @MainActor func markSubredditAsUnpostedRemovesId() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])
    capture.markSubredditAsPosted(sub1.id)
    capture.markSubredditAsPosted(sub2.id)

    #expect(capture.status == .posted)
    capture.markSubredditAsUnposted(sub1.id)

    #expect(!capture.postedSubredditIDs.contains(sub1.id))
    #expect(capture.postedSubredditIDs.contains(sub2.id))
    #expect(capture.status == .queued)
    #expect(capture.postedAt == nil)
}

@Test @MainActor func markAsPostedFillsAllSubredditIDs() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])

    capture.markAsPosted()

    #expect(capture.postedSubredditIDs.count == 2)
    #expect(capture.postedSubredditIDs.contains(sub1.id))
    #expect(capture.postedSubredditIDs.contains(sub2.id))
}

@Test @MainActor func timingEngineExcludesPartiallyPostedSubreddits() throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let event1 = SubredditEvent(name: "E1", subreddit: sub1, oneOffDate: now.addingTimeInterval(3600))
    let event2 = SubredditEvent(name: "E2", subreddit: sub2, oneOffDate: now.addingTimeInterval(3600))

    let capture = Capture(text: "Draft", subreddits: [sub1, sub2])
    capture.markSubredditAsPosted(sub1.id)

    let engine = TimingEngine()
    engine.refresh(events: [event1, event2], captures: [capture], now: now)

    let window1 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub1.id }
    let window2 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub2.id }

    #expect(window1?.matchingCaptureCount == 0)
    #expect(window2?.matchingCaptureCount == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `postedSubredditIDs` property and methods don't exist yet.

- [ ] **Step 3: Add `postedSubredditIDs` and methods to `Capture`**

In `Sources/Models/Capture.swift`, add the new property after `postedURL` (line 20):

```swift
var postedSubredditIDs: [UUID]
```

Update the `init` to initialize it (add after `self.postedURL = nil`):

```swift
self.postedSubredditIDs = []
```

Update `markAsPosted` to fill all subreddit IDs:

```swift
func markAsPosted(postedURL: String? = nil) {
    self.status = .posted
    self.postedAt = Date()
    self.postedURL = postedURL
    self.postedSubredditIDs = subreddits.map(\.id)
}
```

Add new methods after `markAsQueued()`:

```swift
func markSubredditAsPosted(_ subredditId: UUID) {
    guard !postedSubredditIDs.contains(subredditId) else { return }
    postedSubredditIDs.append(subredditId)
    if Set(postedSubredditIDs) == Set(subreddits.map(\.id)) {
        status = .posted
        postedAt = Date()
    }
}

func markSubredditAsUnposted(_ subredditId: UUID) {
    postedSubredditIDs.removeAll { $0 == subredditId }
    if status == .posted {
        status = .queued
        postedAt = nil
    }
}
```

Update `markAsQueued` to also clear `postedSubredditIDs`:

```swift
func markAsQueued() {
    self.status = .queued
    self.postedAt = nil
    self.postedURL = nil
    self.postedSubredditIDs = []
}
```

- [ ] **Step 4: Update `TimingEngine` to respect `postedSubredditIDs`**

In `Sources/Services/TimingEngine.swift`, update the capture counting loop in `refresh()` (lines 67-71):

```swift
// Old:
for capture in captures where capture.status == .queued {
    for sub in capture.subreddits {
        queuedCountBySubredditId[sub.id, default: 0] += 1
    }
}

// New:
for capture in captures where capture.status == .queued {
    for sub in capture.subreddits {
        if !capture.postedSubredditIDs.contains(sub.id) {
            queuedCountBySubredditId[sub.id, default: 0] += 1
        }
    }
}
```

- [ ] **Step 5: Update timing signature to include `postedSubredditIDs`**

In `Sources/Utilities/PopoverTimingPresentation.swift`, update `captureTimingSignature`:

```swift
// Old:
static func captureTimingSignature(from captures: [Capture]) -> [String] {
    captures.map { capture in
        let subIds = capture.subreddits.map(\.id.uuidString).sorted().joined(separator: ",")
        return "\(capture.id.uuidString):\(capture.status.rawValue):\(subIds)"
    }
}

// New:
static func captureTimingSignature(from captures: [Capture]) -> [String] {
    captures.map { capture in
        let subIds = capture.subreddits.map(\.id.uuidString).sorted().joined(separator: ",")
        let postedIds = capture.postedSubredditIDs.map(\.uuidString).sorted().joined(separator: ",")
        return "\(capture.id.uuidString):\(capture.status.rawValue):\(subIds):\(postedIds)"
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `make test`
Expected: All new and existing tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Models/Capture.swift Sources/Services/TimingEngine.swift Sources/Utilities/PopoverTimingPresentation.swift Tests/RedditReminderTests/CapturePerSubredditPostingTests.swift
git commit -m "feat: per-subreddit posting status on Capture model and TimingEngine"
```

---

### Task 4: Per-Subreddit Posting Status — Backup

**Files:**
- Modify: `Sources/Services/BackupTypes.swift:136-149`
- Modify: `Sources/Services/BackupMappers.swift:48-65`
- Modify: `Sources/Services/BackupService.swift:144-167`

- [ ] **Step 1: Add `postedSubredditIDs` to `BackupCapture`**

In `Sources/Services/BackupTypes.swift`, add to `BackupCapture` struct after `subredditIds`:

```swift
// Old:
var subredditIds: [UUID]

// New:
var subredditIds: [UUID]
var postedSubredditIDs: [UUID]? = nil
```

Use optional with `nil` default so existing backup files without this field still decode.

- [ ] **Step 2: Update `BackupCapture.init(capture:)` mapper**

In `Sources/Services/BackupMappers.swift`, add `postedSubredditIDs` to the `BackupCapture` init:

```swift
extension BackupCapture {
    init(capture: Capture) {
        self.init(
            id: capture.id,
            title: capture.title,
            text: capture.text,
            notes: capture.notes,
            links: capture.links,
            mediaRefs: capture.mediaRefs,
            status: capture.status,
            createdAt: capture.createdAt,
            postedAt: capture.postedAt,
            postedURL: capture.postedURL,
            projectId: capture.project?.id,
            subredditIds: capture.subreddits.map(\.id),
            postedSubredditIDs: capture.postedSubredditIDs.isEmpty ? nil : capture.postedSubredditIDs
        )
    }
}
```

- [ ] **Step 3: Restore `postedSubredditIDs` on import**

In `Sources/Services/BackupService.swift`, in the `insert` method's capture loop (around line 165), add after `capture.postedURL = item.postedURL`:

```swift
capture.postedSubredditIDs = item.postedSubredditIDs ?? []
```

- [ ] **Step 4: Run tests to verify backup still works**

Run: `make test`
Expected: All existing backup tests pass (BackupServiceTests, BackupImportValidationTests, BackupImportTransactionTests). The new optional field decodes as `nil` from old backups, so backward compatibility is preserved.

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/BackupTypes.swift Sources/Services/BackupMappers.swift Sources/Services/BackupService.swift
git commit -m "feat: include postedSubredditIDs in backup export/import"
```

---

### Task 5: Per-Subreddit Posting Status — Post Handoff UI

**Files:**
- Modify: `Sources/Views/PostHandoffView.swift`
- Modify: `Sources/Views/PostHandoffViewHelpers.swift`
- Modify: `Sources/Views/PopoverContentActions.swift`

- [ ] **Step 1: Add per-subreddit posting callbacks to `PostHandoffView`**

In `Sources/Views/PostHandoffView.swift`, add new properties after `onClose`:

```swift
var onMarkSubredditPosted: ((UUID) -> Void)? = nil
var onMarkSubredditUnposted: ((UUID) -> Void)? = nil
```

- [ ] **Step 2: Update the destination section to show per-subreddit toggles**

Replace the `destinationSection` computed property in `PostHandoffView.swift`:

```swift
private var destinationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
        sectionHeader("Destination")

        if capture.subreddits.isEmpty {
            Text("No subreddit selected")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sortedSubreddits, id: \.id) { subreddit in
                    let isPosted = capture.postedSubredditIDs.contains(subreddit.id)
                    HStack(spacing: 8) {
                        Text(subreddit.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isPosted ? .secondary : AppColors.redditOrange)
                            .strikethrough(isPosted)

                        Spacer()

                        Button(action: {
                            if isPosted {
                                onMarkSubredditUnposted?(subreddit.id)
                            } else {
                                onMarkSubredditPosted?(subreddit.id)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isPosted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                Text(isPosted ? "Posted" : "Not posted")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(isPosted ? Color(red: 0.13, green: 0.77, blue: 0.37) : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPosted ? "Unmark \(subreddit.name) as posted" : "Mark \(subreddit.name) as posted")
                        .accessibilityIdentifier("postHandoff.subreddit.\(subreddit.name)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isPosted ? Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.06) : AppColors.redditOrange.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Wire up per-subreddit callbacks in `PopoverContentActions.swift`**

Update `openPostHandoff` in `PopoverContentActions.swift`:

```swift
func openPostHandoff(for capture: Capture) {
    let view = PostHandoffView(
        capture: capture,
        checklistItems: postingChecklistItems(for: capture),
        onCopyTitle: { copyPostTitle(for: capture) },
        onCopyBody: { copyPostBody(for: capture) },
        onCopyLinks: { copyPostLinks(for: capture) },
        onCopyAll: { copyPostHandoffText(for: capture) },
        onOpenSubmit: { openRedditSubmitPage(for: capture) },
        onMarkPosted: { markCaptureAsPosted(capture) },
        onClose: { menuBarController.closePostHandoffWindow() },
        onMarkSubredditPosted: { subredditId in
            capture.markSubredditAsPosted(subredditId)
            do { try modelContext.save() } catch {
                NSLog("RedditReminder: mark subreddit posted failed: \(error)")
                modelContext.rollback()
            }
            onAppStateChanged()
        },
        onMarkSubredditUnposted: { subredditId in
            capture.markSubredditAsUnposted(subredditId)
            do { try modelContext.save() } catch {
                NSLog("RedditReminder: unmark subreddit posted failed: \(error)")
                modelContext.rollback()
            }
            onAppStateChanged()
        }
    )
    menuBarController.showPostHandoffWindow(title: handoffWindowTitle(for: capture), content: view)
}
```

- [ ] **Step 4: Build and verify**

Run: `make build`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/Views/PostHandoffView.swift Sources/Views/PostHandoffViewHelpers.swift Sources/Views/PopoverContentActions.swift
git commit -m "feat: per-subreddit posting toggles in Post Handoff view"
```

---

### Task 6: Expandable Event Banner

**Files:**
- Modify: `Sources/Views/EventBannerView.swift`

- [ ] **Step 1: Add expanded state and disclosure chevron**

In `EventBannerView.swift`, add a binding for expansion state. Change the struct to accept a binding:

```swift
struct EventBannerView: View {
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    var onTap: ((TimingEngine.UpcomingWindow) -> Void)? = nil
    @State private var isExpanded: Bool = false
```

- [ ] **Step 2: Add disclosure chevron to the banner and expanded rows**

Update the `body` to add a chevron and expanded rows. Replace the entire `body`:

```swift
var body: some View {
    if let next = upcomingWindows.first {
        VStack(spacing: 0) {
            Button(action: {
                if upcomingWindows.count > 1 {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } else {
                    onTap?(next)
                }
            }) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(AppColors.redditOrange)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("UPCOMING")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.redditOrange)
                            .tracking(0.5)

                        if let sub = next.event.subreddit {
                            eventTitle("\(sub.name) — \(next.event.name)", event: next.event)
                        } else {
                            eventTitle(next.event.name, event: next.event)
                        }

                        HStack(spacing: 4) {
                            Text(Self.relativeTime(next.eventDate))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            if let readyText = Self.readyCaptureText(count: next.matchingCaptureCount) {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(readyText)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            if upcomingWindows.count > 1 {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text("and \(upcomingWindows.count - 1) more")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColors.redditOrange)
                            }
                        }
                    }
                    .padding(.leading, 10)

                    Spacer(minLength: 0)

                    if upcomingWindows.count > 1 {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 4)
                    }
                }
                .padding(10)
                .background(AppColors.redditOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Self.accessibilityLabel(for: next, additionalWindowCount: upcomingWindows.count - 1))
            .accessibilityLabel(
                Self.accessibilityLabel(for: next, additionalWindowCount: upcomingWindows.count - 1)
            )

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(upcomingWindows.dropFirst(), id: \.event.id) { window in
                        Button(action: { onTap?(window) }) {
                            HStack(spacing: 8) {
                                if let sub = window.event.subreddit {
                                    Text(sub.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                } else {
                                    Text(window.event.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                Text(Self.relativeTime(window.eventDate))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)

                                if let readyText = Self.readyCaptureText(count: window.matchingCaptureCount) {
                                    Text("·")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                    Text(readyText)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }

                                if let dotColor = UrgencyPresentation.color(for: window.urgency) {
                                    Circle()
                                        .fill(dotColor)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Self.accessibilityLabel(for: window, additionalWindowCount: 0))
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `make build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/EventBannerView.swift
git commit -m "feat: expandable event banner with disclosure chevron"
```

---

### Task 7: Integration Test — Full Capture Lifecycle

**Files:**
- Create: `Tests/RedditReminderTests/CaptureLifecycleIntegrationTests.swift`

- [ ] **Step 1: Write the lifecycle integration test file**

```swift
import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import RedditReminder

private let integrationNow = Date(timeIntervalSince1970: 1_700_000_000)

private final class RecordingNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var removedAll = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationStatus == .authorized
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        handler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
    }

    func removeAllPendingNotificationRequests() {
        removedAll = true
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }
}

@Test @MainActor func fullLifecycleFromCaptureToPosted() async throws {
    let sub = Subreddit(name: "r/SideProject")
    let eventDate = integrationNow.addingTimeInterval(3 * 3600)
    let event = SubredditEvent(
        name: "Show-off Saturday",
        subreddit: sub,
        oneOffDate: eventDate,
        reminderLeadMinutes: 60
    )
    let capture = Capture(text: "My side project launch", subreddits: [sub])

    // 1. TimingEngine picks up the capture
    let engine = TimingEngine()
    engine.refresh(events: [event], captures: [capture], now: integrationNow)

    #expect(engine.upcomingWindows.count == 1)
    #expect(engine.upcomingWindows[0].matchingCaptureCount == 1)
    #expect(engine.upcomingWindows[0].urgency == .medium)

    // 2. NotificationScheduler schedules the notification
    let center = RecordingNotificationCenter()
    let service = NotificationService(center: center)
    let suiteName = "LifecycleIntegration-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(true, forKey: SettingsKey.notificationsEnabled)

    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let staleCount = await scheduler.schedule(
        activeEvents: [event],
        windows: engine.upcomingWindows,
        now: integrationNow
    )

    #expect(staleCount == 0)
    #expect(center.addedRequests.count == 1)
    #expect(center.addedRequests[0].content.body == "1 captures ready for r/SideProject")

    // 3. Mark as posted — count drops to 0
    capture.markAsPosted()
    engine.refresh(events: [event], captures: [capture], now: integrationNow)

    #expect(engine.upcomingWindows[0].matchingCaptureCount == 0)
    #expect(capture.status == .posted)
    #expect(capture.postedSubredditIDs.contains(sub.id))
}

@Test @MainActor func perSubredditPostingLifecycle() async throws {
    let sub1 = Subreddit(name: "r/webdev")
    let sub2 = Subreddit(name: "r/SideProject")
    let sub3 = Subreddit(name: "r/MacApps")

    let eventDate = integrationNow.addingTimeInterval(3 * 3600)
    let event1 = SubredditEvent(name: "E1", subreddit: sub1, oneOffDate: eventDate)
    let event2 = SubredditEvent(name: "E2", subreddit: sub2, oneOffDate: eventDate)
    let event3 = SubredditEvent(name: "E3", subreddit: sub3, oneOffDate: eventDate)

    let capture = Capture(text: "Cross-post draft", subreddits: [sub1, sub2, sub3])

    let engine = TimingEngine()
    engine.refresh(events: [event1, event2, event3], captures: [capture], now: integrationNow)

    // All 3 windows show 1 ready capture
    for window in engine.upcomingWindows {
        #expect(window.matchingCaptureCount == 1)
    }

    // Post to sub1 only
    capture.markSubredditAsPosted(sub1.id)
    #expect(capture.status == .queued)
    engine.refresh(events: [event1, event2, event3], captures: [capture], now: integrationNow)

    let w1 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub1.id }
    let w2 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub2.id }
    let w3 = engine.upcomingWindows.first { $0.event.subreddit?.id == sub3.id }
    #expect(w1?.matchingCaptureCount == 0)
    #expect(w2?.matchingCaptureCount == 1)
    #expect(w3?.matchingCaptureCount == 1)

    // Post to remaining
    capture.markSubredditAsPosted(sub2.id)
    capture.markSubredditAsPosted(sub3.id)
    #expect(capture.status == .posted)

    engine.refresh(events: [event1, event2, event3], captures: [capture], now: integrationNow)
    for window in engine.upcomingWindows {
        #expect(window.matchingCaptureCount == 0)
    }
}
```

- [ ] **Step 2: Run tests**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/RedditReminderTests/CaptureLifecycleIntegrationTests.swift
git commit -m "test: capture lifecycle integration tests with per-subreddit posting"
```

---

### Task 8: BackupService Round-Trip Fidelity Test

**Files:**
- Create: `Tests/RedditReminderTests/BackupRoundTripTests.swift`

- [ ] **Step 1: Write the round-trip test file**

```swift
import Testing
import Foundation
import SwiftData
@testable import RedditReminder

@Test @MainActor func backupRoundTripPreservesAllFields() throws {
    let container = try makeCRUDContainer()
    let context = container.mainContext

    // Seed data
    let project = Project(name: "Launch", projectDescription: "Q2 launch", color: "blue")
    project.archived = false
    context.insert(project)

    let sub1 = Subreddit(name: "r/webdev", sortOrder: 0, postingChecklist: "Check rules\nAdd flair")
    let sub2 = Subreddit(name: "r/SideProject", sortOrder: 1)
    context.insert(sub1)
    context.insert(sub2)

    let event1 = SubredditEvent(
        name: "Weekly",
        subreddit: sub1,
        rrule: "FREQ=WEEKLY;BYDAY=MO",
        recurrenceHour: 10,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York",
        reminderLeadMinutes: 30,
        isGeneratedFromHeuristics: true,
        generationKey: "r/webdev-weekday"
    )
    let event2 = SubredditEvent(
        name: "Launch Day",
        subreddit: sub2,
        oneOffDate: Date(timeIntervalSince1970: 1_800_000_000),
        reminderLeadMinutes: 60
    )
    context.insert(event1)
    context.insert(event2)

    let capture1 = Capture(
        title: "Post Title",
        text: "Post body text",
        notes: "Remember to add images",
        links: ["https://example.com", "https://github.com"],
        mediaRefs: ["img1.png", "img2.jpg"],
        project: project,
        subreddits: [sub1, sub2]
    )
    let capture2 = Capture(text: "Quick thought", subreddits: [sub1])
    capture2.markSubredditAsPosted(sub1.id)

    let capture3 = Capture(text: "Fully posted", subreddits: [sub1, sub2])
    capture3.markAsPosted(postedURL: "https://reddit.com/r/webdev/123")

    context.insert(capture1)
    context.insert(capture2)
    context.insert(capture3)
    try context.save()

    // Snapshot original state
    let originalProjectIds = [project.id]
    let originalSubIds = [sub1.id, sub2.id]
    let originalEventIds = [event1.id, event2.id]
    let originalCaptureIds = [capture1.id, capture2.id, capture3.id]

    // Export
    let service = BackupService()
    let data = try service.exportBackup(from: context)

    // Wipe
    for c in try context.fetch(FetchDescriptor<Capture>()) { context.delete(c) }
    for e in try context.fetch(FetchDescriptor<SubredditEvent>()) { context.delete(e) }
    for p in try context.fetch(FetchDescriptor<Project>()) { context.delete(p) }
    for s in try context.fetch(FetchDescriptor<Subreddit>()) { context.delete(s) }
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)

    // Import
    let suiteName = "RoundTrip-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try service.importBackup(from: data, into: context, defaults: defaults)

    // Verify projects
    let restoredProjects = try context.fetch(FetchDescriptor<Project>())
    #expect(restoredProjects.count == 1)
    let rp = restoredProjects[0]
    #expect(rp.id == originalProjectIds[0])
    #expect(rp.name == "Launch")
    #expect(rp.projectDescription == "Q2 launch")
    #expect(rp.color == "blue")
    #expect(rp.archived == false)

    // Verify subreddits
    let restoredSubs = try context.fetch(FetchDescriptor<Subreddit>())
    #expect(restoredSubs.count == 2)
    let rs1 = restoredSubs.first { $0.id == originalSubIds[0] }!
    #expect(rs1.name == "r/webdev")
    #expect(rs1.sortOrder == 0)
    #expect(rs1.postingChecklist == "Check rules\nAdd flair")
    let rs2 = restoredSubs.first { $0.id == originalSubIds[1] }!
    #expect(rs2.name == "r/SideProject")

    // Verify events
    let restoredEvents = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(restoredEvents.count == 2)
    let re1 = restoredEvents.first { $0.id == originalEventIds[0] }!
    #expect(re1.name == "Weekly")
    #expect(re1.rrule == "FREQ=WEEKLY;BYDAY=MO")
    #expect(re1.recurrenceHour == 10)
    #expect(re1.recurrenceMinute == 30)
    #expect(re1.recurrenceTimeZoneIdentifier == "America/New_York")
    #expect(re1.reminderLeadMinutes == 30)
    #expect(re1.isGeneratedFromHeuristics == true)
    #expect(re1.generationKey == "r/webdev-weekday")
    #expect(re1.subreddit?.id == originalSubIds[0])
    let re2 = restoredEvents.first { $0.id == originalEventIds[1] }!
    #expect(re2.oneOffDate == Date(timeIntervalSince1970: 1_800_000_000))

    // Verify captures
    let restoredCaptures = try context.fetch(FetchDescriptor<Capture>())
    #expect(restoredCaptures.count == 3)

    let rc1 = restoredCaptures.first { $0.id == originalCaptureIds[0] }!
    #expect(rc1.title == "Post Title")
    #expect(rc1.text == "Post body text")
    #expect(rc1.notes == "Remember to add images")
    #expect(rc1.links == ["https://example.com", "https://github.com"])
    #expect(rc1.status == .queued)
    #expect(rc1.project?.id == originalProjectIds[0])
    #expect(Set(rc1.subreddits.map(\.id)) == Set(originalSubIds))
    #expect(rc1.postedSubredditIDs.isEmpty)

    let rc2 = restoredCaptures.first { $0.id == originalCaptureIds[1] }!
    #expect(rc2.status == .queued)
    #expect(rc2.postedSubredditIDs == [originalSubIds[0]])

    let rc3 = restoredCaptures.first { $0.id == originalCaptureIds[2] }!
    #expect(rc3.status == .posted)
    #expect(rc3.postedURL == "https://reddit.com/r/webdev/123")
    #expect(Set(rc3.postedSubredditIDs) == Set(originalSubIds))
}

@Test @MainActor func backupRoundTripEmptyData() throws {
    let container = try makeCRUDContainer()
    let context = container.mainContext

    let service = BackupService()
    let data = try service.exportBackup(from: context)

    let suiteName = "RoundTripEmpty-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let result = try service.importBackup(from: data, into: context, defaults: defaults)

    #expect(result.preview.captures == 0)
    #expect(result.preview.projects == 0)
    #expect(result.preview.subreddits == 0)
    #expect(result.preview.events == 0)
}
```

- [ ] **Step 2: Run tests**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/RedditReminderTests/BackupRoundTripTests.swift
git commit -m "test: backup export/import round-trip fidelity tests"
```

---

### Task 9: Notification Scheduler Permission Tests

**Files:**
- Create: `Tests/RedditReminderTests/NotificationSchedulerPermissionTests.swift`

- [ ] **Step 1: Write the permission test file**

```swift
import Testing
import Foundation
import UserNotifications
@testable import RedditReminder

private final class RecordingNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedAll = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationStatus == .authorized
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        handler?(nil)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func removeAllPendingNotificationRequests() {
        removedAll = true
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }
}

private func makeTestDefaults(
    notificationsEnabled: Bool = true
) -> (UserDefaults, String) {
    let suiteName = "PermissionTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(notificationsEnabled, forKey: SettingsKey.notificationsEnabled)
    return (defaults, suiteName)
}

private func makeTestWindow() -> TimingEngine.UpcomingWindow {
    let sub = Subreddit(name: "r/Test")
    let event = SubredditEvent(
        name: "Peak",
        subreddit: sub,
        oneOffDate: Date().addingTimeInterval(3600),
        reminderLeadMinutes: 0
    )
    return TimingEngine.UpcomingWindow(
        event: event,
        eventDate: event.oneOffDate!,
        notificationFireDate: Date().addingTimeInterval(300),
        urgency: .high,
        matchingCaptureCount: 2
    )
}

@Test @MainActor func permissionDeniedCancelsAllAndReturnsNil() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .denied
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: true)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == nil)
    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}

@Test @MainActor func permissionNotDeterminedCancelsAllAndReturnsNil() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .notDetermined
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: true)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == nil)
    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}

@Test @MainActor func notificationsDisabledInSettingsCancelsAll() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .authorized
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: false)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == nil)
    #expect(center.removedAll)
    #expect(center.addedRequests.isEmpty)
}

@Test @MainActor func authorizedAndEnabledSchedulesNotifications() async {
    let center = RecordingNotificationCenter()
    center.authorizationStatus = .authorized
    let (defaults, suiteName) = makeTestDefaults(notificationsEnabled: true)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let service = NotificationService(center: center)
    let scheduler = NotificationScheduler(notificationService: service, defaults: defaults)
    let window = makeTestWindow()

    let result = await scheduler.schedule(
        activeEvents: [window.event],
        windows: [window]
    )

    #expect(result == 0)
    #expect(!center.removedAll)
    #expect(center.addedRequests.count == 1)
}
```

- [ ] **Step 2: Run tests**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/RedditReminderTests/NotificationSchedulerPermissionTests.swift
git commit -m "test: notification scheduler permission denial and settings tests"
```

---

### Task 10: Timezone Edge Case Tests

**Files:**
- Create: `Tests/RedditReminderTests/TimingEngineTimezoneEdgeCaseTests.swift`

- [ ] **Step 1: Write the timezone edge case test file**

```swift
import Testing
import Foundation
@testable import RedditReminder

@Test @MainActor func crossTimezoneResolution() {
    let sub = Subreddit(name: "r/webdev")
    let event = SubredditEvent(
        name: "Morning Post",
        subreddit: sub,
        rrule: "FREQ=WEEKLY;BYDAY=MO",
        recurrenceHour: 10,
        recurrenceMinute: 0,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )

    // Use a UTC time: Sunday 2023-11-12 20:00 UTC = Sunday 3:00 PM ET
    // Next Monday 10:00 AM ET = Monday 2023-11-13 15:00 UTC
    let utcCal = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = utcCal.date(from: DateComponents(year: 2023, month: 11, day: 12, hour: 20, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)

    // Verify the window is on Monday in ET
    var etCal = Calendar(identifier: .gregorian)
    etCal.timeZone = TimeZone(identifier: "America/New_York")!
    let components = etCal.dateComponents([.weekday, .hour, .minute], from: window!)
    #expect(components.weekday == 2)  // Monday
    #expect(components.hour == 10)
    #expect(components.minute == 0)
}

@Test @MainActor func dayBoundaryTimezone() {
    let sub = Subreddit(name: "r/japan")
    let event = SubredditEvent(
        name: "Daily",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 1,
        recurrenceMinute: 0,
        recurrenceTimeZoneIdentifier: "Asia/Tokyo"
    )

    // 11:00 PM UTC = 8:00 AM JST next day. 1:00 AM JST has passed.
    // Next occurrence should be 1:00 AM JST the day AFTER the JST day.
    let utcCal = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let now = utcCal.date(from: DateComponents(year: 2023, month: 11, day: 15, hour: 23, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)
    #expect(window! > now)

    var jstCal = Calendar(identifier: .gregorian)
    jstCal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    let components = jstCal.dateComponents([.hour, .minute], from: window!)
    #expect(components.hour == 1)
    #expect(components.minute == 0)
}

@Test @MainActor func dstSpringForwardProducesValidDate() {
    let sub = Subreddit(name: "r/test")
    // 2:30 AM ET doesn't exist during spring forward (2024-03-10 in US)
    let event = SubredditEvent(
        name: "Early",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 2,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )

    var etCal = Calendar(identifier: .gregorian)
    etCal.timeZone = TimeZone(identifier: "America/New_York")!
    // March 9, 2024 11:00 PM ET — just before spring forward
    let now = etCal.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 23, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    // Should still produce a valid date (not nil, not crash)
    #expect(window != nil)
    #expect(window! > now)
}

@Test @MainActor func dstFallBackDoesNotDoubleCount() {
    let sub = Subreddit(name: "r/test")
    // 1:30 AM ET is ambiguous during fall back (2024-11-03 in US)
    let event = SubredditEvent(
        name: "Ambiguous",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 1,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )

    var etCal = Calendar(identifier: .gregorian)
    etCal.timeZone = TimeZone(identifier: "America/New_York")!
    // Nov 3, 2024 12:00 AM ET — before the ambiguous hour
    let now = etCal.date(from: DateComponents(year: 2024, month: 11, day: 3, hour: 0, minute: 0))!

    let window = TimingEngine.nextWindow(for: event, after: now)
    #expect(window != nil)
    #expect(window! > now)

    // Should produce exactly one occurrence, not two
    let engine = TimingEngine()
    let windowEvent = SubredditEvent(
        name: "Ambiguous",
        subreddit: sub,
        rrule: "FREQ=DAILY",
        recurrenceHour: 1,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York"
    )
    let capture = Capture(text: "Test", subreddits: [sub])
    engine.refresh(events: [windowEvent], captures: [capture], now: now, horizonDays: 1)
    #expect(engine.upcomingWindows.count == 1)
}
```

- [ ] **Step 2: Run tests**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/RedditReminderTests/TimingEngineTimezoneEdgeCaseTests.swift
git commit -m "test: timezone edge cases including DST transitions"
```

---

### Task 11: UI Test Expansion

**Files:**
- Create: `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift`

- [ ] **Step 1: Write the UI workflow tests**

```swift
import XCTest

final class RedditReminderWorkflowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--seed-qa"]
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testCreateCaptureWindowAppears() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()
        app.typeKey("n", modifierFlags: .command)

        let captureWindow = app.windows["New Capture"]
        XCTAssertTrue(captureWindow.waitForExistence(timeout: 3))

        let titleField = captureWindow.textFields["captureWindow.title"]
        XCTAssertTrue(titleField.exists)

        let saveButton = captureWindow.buttons["captureWindow.save"]
        XCTAssertTrue(saveButton.exists)

        let cancelButton = captureWindow.buttons["captureWindow.cancel"]
        XCTAssertTrue(cancelButton.exists)
    }

    func testPreferencesTabNavigation() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()
        app.typeKey(",", modifierFlags: .command)

        let prefsWindow = app.windows["RedditReminder Preferences"]
        XCTAssertTrue(prefsWindow.waitForExistence(timeout: 3))

        let tabs = ["Channels", "Planner", "Projects", "General", "Backup", "Notifications"]
        for tab in tabs {
            let tabButton = prefsWindow.buttons["preferences.tab.\(tab)"]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 2), "Tab '\(tab)' should exist")
            tabButton.click()
            // Brief pause for tab content to load
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    func testDeleteConfirmationAppears() throws {
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5)
                || app.wait(for: .runningBackground, timeout: 5)
        )

        app.activate()

        // With --seed-qa, there should be capture cards in the popover.
        // Right-click to access the context menu.
        let captureCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "capture")
        ).firstMatch
        guard captureCard.waitForExistence(timeout: 3) else {
            XCTFail("No capture cards found — QA fixtures may not have seeded")
            return
        }

        captureCard.rightClick()
        let deleteMenuItem = app.menuItems["Delete"]
        guard deleteMenuItem.waitForExistence(timeout: 2) else {
            XCTFail("Delete menu item not found in context menu")
            return
        }
        deleteMenuItem.click()

        // The NSAlert confirmation should appear
        let alert = app.dialogs.firstMatch
        XCTAssertTrue(
            alert.waitForExistence(timeout: 3),
            "Delete confirmation dialog should appear"
        )

        // Cancel to preserve the capture
        let cancelButton = alert.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.click()
        }
    }
}
```

- [ ] **Step 2: Run UI tests**

Run: `make ui-test`
Expected: Tests pass (some may be flaky depending on QA fixture seeding and popover lifecycle — that's acceptable for an initial pass).

- [ ] **Step 3: Commit**

```bash
git add Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift
git commit -m "test: UI workflow tests for capture creation, preferences, and delete confirmation"
```

---

### Task 12: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `make test`
Expected: All unit tests pass.

- [ ] **Step 2: Run full build**

Run: `make build`
Expected: Build succeeds with zero errors and zero warnings from changed files.

- [ ] **Step 3: Verify no regressions in existing tests**

Run: `make test 2>&1 | tail -5`
Expected: Output shows all tests passed, no failures.
