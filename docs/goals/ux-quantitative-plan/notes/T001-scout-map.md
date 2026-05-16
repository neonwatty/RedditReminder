# T001 Scout Map

## Surface Inventory

- First-run and launch: `Sources/App/AppDelegate.swift`, `Sources/Views/OnboardingEmptyView.swift`, `Sources/Views/NotificationsTabView.swift`.
- Queue root: `Sources/Views/PopoverContentView.swift`, `Sources/Views/PopoverContentEmptyStates.swift`, `Sources/Views/EventBannerView.swift`, `Sources/Views/CaptureCardView.swift`.
- Planner: `Sources/Views/PlannerTabView.swift`, `Sources/Utilities/PlannerPresentation.swift`, `Sources/Utilities/PlannerEventLoader.swift`, `Sources/Services/TimingEngine.swift`.
- Channels: `Sources/Views/ChannelsView.swift`, `Sources/Views/SubredditRow.swift`, `Sources/Utilities/SubredditInputValidation.swift`, `Sources/Utilities/SubredditPersistenceActions.swift`.
- Capture form: `Sources/Views/CaptureWindowView.swift`, `Sources/Views/CaptureSubredditPicker.swift`, `Sources/Views/CaptureLinksSection.swift`, `Sources/Views/CaptureMediaSection.swift`, `Sources/Views/CaptureMediaChips.swift`.
- Settings/Preferences: `Sources/Views/PreferencesView.swift`, `Sources/Views/GeneralTabView.swift`, `Sources/Views/NotificationsTabView.swift`, `Sources/Views/BackupSectionView.swift`.
- Posted/menu bar: `Sources/Views/PostedListView.swift`, `Sources/Services/MenuBarController.swift`, `Sources/Views/PopoverChromeViews.swift`.

## Evidence By Theme

### First-run Trust And Recovery

- Confirmed launch-time notification permission request: `Sources/App/AppDelegate.swift:121-124` sets notification delegate/categories, then calls `Task { _ = await notificationService.requestPermission() }`.
- Confirmed user-intent request path also exists: `Sources/Views/NotificationsTabView.swift:27-30` has an explicit "Request Permission" button.
- Confirmed queue empty-state gap: `Sources/Views/PopoverContentView.swift:150-170` shows onboarding only when `displayedCaptures.isEmpty && timingEngine.upcomingWindows.isEmpty`; when windows exist and no captures exist, it renders `EventBannerView` plus an empty capture list and no create-capture CTA.
- Existing onboarding copy is directionally good and tested: `Tests/RedditReminderTests/PreferencesViewTests.swift:32-48`.

### Capture And Channel Recovery

- Capture form owns draft state locally in `@State` properties: `Sources/Views/CaptureWindowView.swift:20-32`.
- No-channel path calls an external route via `onAddSubreddit`: `Sources/Views/CaptureSubredditPicker.swift:13-34`; parent passes `onAddSubreddit` from capture form at `Sources/Views/CaptureWindowView.swift:94-99`.
- Because no durable draft object is visible in source, navigating away from capture to Channels can lose entered form state unless parent route preservation exists elsewhere.
- Channel add has local normalization, duplicate detection, and preview feedback: `Sources/Utilities/SubredditInputValidation.swift:13-26`; persistence adds locally and syncs generated events: `Sources/Utilities/SubredditPersistenceActions.swift:17-48`.
- UI-level live Reddit verification is not present in the app path inspected; CLI docs expose verification separately.

### Planner Workflow

- Planner is explicitly 7-day scoped in the header: `Sources/Views/PlannerTabView.swift:78-95`.
- Calendar days are always seven days in presentation tests: `Tests/RedditReminderTests/PlannerPresentationTests.swift:40-61`.
- Planner row actions are generic closures: `Sources/Views/PlannerTabView.swift:261-270`; `onCreateCapture` currently carries no window or subreddit context.
- Calendar pills show only urgency and time in visible text; subreddit/title is hover help only: `Sources/Views/PlannerTabView.swift:319-332`.
- Calendar overflow is a text count only: `Sources/Views/PlannerTabView.swift:297-305`.
- Existing tests cover grouping, readiness text, and seven-day generation, but not planner action routing or visible calendar labels.

### Native macOS Polish And Accessibility

- Header settings/new-capture controls use `.buttonStyle(.plain)` and small fonts: `Sources/Views/PopoverChromeViews.swift:96-111`.
- Workspace tabs are five items at 10 pt in the popover header: `Sources/Views/PopoverChromeViews.swift:126-140`.
- Capture Save/Cancel use plain orange/secondary text: `Sources/Views/CaptureWindowView.swift:176-190`.
- Preferences tabs are custom plain buttons: `Sources/Views/PreferencesView.swift:34-51`.
- Posted list action buttons are 18x18 pt despite labels/help: `Sources/Views/PostedListView.swift:113-130`.
- Media chips have stable identifiers but missing explicit accessibility labels on preview/remove/restore buttons: `Sources/Views/CaptureMediaChips.swift:15-28` and `Sources/Views/CaptureMediaChips.swift:69-75`.

### Validation And Error Feedback

- Invalid link entry is silently ignored: `Sources/Views/CaptureLinksSection.swift:46-49`.
- File importer failure logs only and does not show a user-visible error: `Sources/Views/CaptureMediaSection.swift:119-124`.
- Unsupported dropped/imported media does show inline error via `mediaSelectionError`: `Sources/Views/CaptureMediaSection.swift:126-130` and `Sources/Views/CaptureMediaSection.swift:165-170`.
- Capture persistence media failures surface only as generic save failure after `onSave` returns false: `Sources/Views/CaptureWindowView.swift:245-260`.

## Existing Verification

- Main test command: `make test` runs `xcodebuild test` for `RedditReminder`.
- UI test command: `make ui-test` runs `RedditReminderUITests`.
- CLI test command: `make cli-test` builds CLI and runs smoke/catalog checks.
- QA command: `make qa` installs debug app and runs `scripts/qa.sh`; it may require Accessibility permission and is higher-friction than unit tests.
- Existing UI tests cover opening capture popover, Preferences tab navigation, and delete confirmation: `Tests/RedditReminderUITests/RedditReminderWorkflowUITests.swift`.
- Existing unit tests cover many utility/model paths, onboarding static copy, planner presentation, media store/persistence, notification scheduling, and accessibility identifiers.

## Test Gaps

- No direct test for "zero launch-time notification permission requests."
- No visible-state test for queue empty while posting windows exist.
- No route/context test for planner "Create capture" from a specific window.
- No test proving no-channel capture draft state survives channel setup or that an inline recovery exists.
- No visible inline error test for invalid links.
- No visible importer-failure feedback test.
- No systematic hit-frame/accessibility-label invariant for touched compact controls.

## Candidate Quantitative Metrics

- Permission trust: exactly 0 notification permission requests during launch; exactly 1 request after explicit "Request Permission" user action.
- Queue recovery: when displayed queued captures count is 0 and upcoming window count is greater than 0, exactly 1 visible empty-queue CTA exists with a stable accessibility identifier; when displayed queued captures count is greater than 0, the CTA does not render.
- Planner actionability: create-capture from a window carries a non-nil subreddit/window context; at least one test asserts the selected event/subreddit identity.
- Calendar visibility: each visible non-empty day cell exposes at least time plus subreddit/channel text without relying on hover; overflow has a deterministic drill-in/filter action or is explicitly deferred.
- Accessibility baseline: touched icon-only buttons have non-empty accessibility labels and help; touched compact buttons have minimum 28x28 pt frame unless a Judge exception is recorded.
- Validation: invalid link and media import failure paths produce visible error text with stable accessibility identifiers; successful link/media flows still pass existing tests.
