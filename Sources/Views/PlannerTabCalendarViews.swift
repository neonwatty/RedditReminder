import SwiftUI

extension PlannerTabView {
  var listView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if eventLoadResult.hitLimit {
          cappedFetchNotice
        }
        ForEach(dayGroups, id: \.day) { group in
          dayGroup(group)
        }
        if hasMoreWindows {
          Button("Load next 50 windows") {
            visibleWindowLimit += 50
          }
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(AppColors.redditOrange)
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity, minHeight: 32)
        }
      }
      .padding(14)
    }
  }

  var calendarView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if eventLoadResult.hitLimit {
          cappedFetchNotice
        }
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(minimum: 48), spacing: 6), count: 7),
          alignment: .leading,
          spacing: 6
        ) {
          ForEach(calendarDays, id: \.day) { day in
            calendarDayCell(day)
          }
        }
      }
      .padding(14)
    }
  }

  var cappedFetchNotice: some View {
    Text(
      "Planner loaded \(eventLoadResult.loadedCount) candidate events. Narrow channels or archive old windows if expected events are missing."
    )
    .font(.system(size: 10))
    .foregroundStyle(.secondary)
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.22))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  var emptyState: some View {
    VStack(spacing: 8) {
      Spacer()
      Text("No posting windows this week")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
      Text("Add channels or adjust peak windows to populate the planner")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
      Button(Self.editChannelsActionText, action: onEditChannels)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
        .buttonStyle(.plain)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  func errorState(_ message: String) -> some View {
    VStack(spacing: 8) {
      Spacer()
      Text("Planner unavailable")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
      Text(message)
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
      Button("Retry", action: refreshTiming)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
        .buttonStyle(.plain)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  func dayGroup(_ group: PlannerDayGroup) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(group.title.uppercased())
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .tracking(0.3)

      VStack(spacing: 0) {
        ForEach(group.windows, id: \.event.id) { window in
          plannerRow(window)
          if window.event.id != group.windows.last?.event.id {
            Divider().padding(.leading, 10)
          }
        }
      }
      .background(.quaternary.opacity(0.22))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
      )
    }
  }

  func plannerRow(_ window: TimingEngine.UpcomingWindow) -> some View {
    HStack(alignment: .top, spacing: 10) {
      urgencyDot(for: window.urgency)
        .padding(.top, 5)

      VStack(alignment: .leading, spacing: 3) {
        Text(EventBannerView.title(for: window))
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        HStack(spacing: 5) {
          Text(timeText(for: window.eventDate))
          Text("·")
          Text(PlannerPresentation.readinessText(for: window.matchingCaptureCount))
            .foregroundStyle(window.matchingCaptureCount == 0 ? AppColors.redditOrange : .secondary)
          Text("·")
          sourceBadge(for: window)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      HStack(spacing: 6) {
        primaryPlannerAction(for: window)
        plannerIconButton(
          systemName: "slider.horizontal.3",
          label: Self.editChannelsActionText,
          action: onEditChannels
        )
        .accessibilityIdentifier("planner.editChannels")
      }
    }
    .padding(10)
  }

  func sourceBadge(for window: TimingEngine.UpcomingWindow) -> some View {
    Text(window.event.isGeneratedFromHeuristics ? "Auto" : "Manual")
      .font(.system(size: 9, weight: .semibold))
      .foregroundStyle(window.event.isGeneratedFromHeuristics ? AppColors.redditOrange : .secondary)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(
        window.event.isGeneratedFromHeuristics ? AppColors.redditOrange.opacity(0.10) : Color.clear
      )
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }

  @ViewBuilder
  func primaryPlannerAction(for window: TimingEngine.UpcomingWindow) -> some View {
    if window.matchingCaptureCount == 0 {
      plannerIconButton(
        systemName: "text.badge.plus",
        label: Self.createCaptureActionText,
        action: { onCreateCaptureForSubreddit(window.event.subreddit) }
      )
      .accessibilityIdentifier(
        PlannerPresentation.createCaptureIdentifier(subredditId: window.event.subreddit?.id)
      )
    } else {
      plannerIconButton(
        systemName: "tray",
        label: Self.viewQueueActionText,
        action: onViewQueue
      )
      .accessibilityIdentifier("planner.viewQueue")
    }
  }

  func plannerIconButton(
    systemName: String,
    label: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
        .frame(width: Self.rowActionHitSize, height: Self.rowActionHitSize)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(RoundedRectangle(cornerRadius: 5))
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
  }

  func calendarDayCell(_ day: PlannerCalendarDay) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      VStack(alignment: .leading, spacing: 1) {
        Text(day.title)
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Text(day.dayNumber)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)
      }

      if day.windows.isEmpty {
        Text("No windows")
          .font(.system(size: 9))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      } else {
        ForEach(day.windows.prefix(3), id: \.event.id) { window in
          calendarWindowPill(window)
        }
        if day.windows.count > 3 {
          Text("+\(day.windows.count - 3) more")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(AppColors.redditOrange)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(8)
    .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
    .background(day.windows.isEmpty ? Color.clear : Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
    )
  }

  func calendarWindowPill(_ window: TimingEngine.UpcomingWindow) -> some View {
    HStack(spacing: 4) {
      urgencyDot(for: window.urgency)
      Text(
        PlannerPresentation.calendarWindowLabel(
          subredditName: window.event.subreddit?.name,
          timeText: timeText(for: window.eventDate)
        )
      )
      .lineLimit(1)
      Spacer(minLength: 0)
      if window.matchingCaptureCount == 0 {
        Button(action: { onCreateCaptureForSubreddit(window.event.subreddit) }) {
          Image(systemName: "plus.circle")
            .font(.system(size: 10, weight: .medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.createCaptureActionText)
        .accessibilityIdentifier(
          PlannerPresentation.calendarCreateCaptureIdentifier(
            subredditId: window.event.subreddit?.id
          )
        )
      } else {
        Button(action: onViewQueue) {
          Image(systemName: "list.bullet")
            .font(.system(size: 10, weight: .medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.viewQueueActionText)
        .accessibilityIdentifier("planner.calendar.viewQueue")
      }
    }
    .font(.system(size: 9, weight: .medium))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 5)
    .padding(.vertical, 3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 5))
    .help(EventBannerView.title(for: window))
  }

  func urgencyDot(for urgency: UrgencyLevel) -> some View {
    Circle()
      .fill(UrgencyPresentation.color(for: urgency) ?? Color.secondary.opacity(0.35))
      .frame(width: 7, height: 7)
      .help(UrgencyPresentation.label(for: urgency))
  }
}
