import SwiftData
import SwiftUI

struct SubredditRow: View {
  @Bindable var sub: Subreddit
  let peakInfo: PeakInfo?
  let isExpanded: Bool
  let onToggle: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onToggle) {
        HStack {
          HStack(spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .font(.system(size: 10))
              .foregroundStyle(isExpanded ? AppColors.redditOrange : .secondary)
            Text(sub.name)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(.primary)
          }
          Spacer()
          if isExpanded {
            Button("Remove", action: onDelete)
              .font(.system(size: 11))
              .foregroundStyle(.red)
              .buttonStyle(.plain)
              .accessibilityLabel("Remove \(sub.name)")
              .accessibilityIdentifier("channels.subredditRow.\(sub.id.uuidString).remove")
          } else {
            VStack(alignment: .trailing, spacing: 2) {
              Text(peakDaysSummaryText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
              if hasPostingChecklist {
                Text("checklist")
                  .font(.system(size: 9))
                  .foregroundStyle(AppColors.redditOrange)
              }
              Text(eventSourceSummary.compactLabel)
                .font(.system(size: 9))
                .foregroundStyle(
                  eventSourceSummary.generatedCount > 0 ? AppColors.redditOrange : .secondary)
            }
          }
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isExpanded ? "Collapse \(sub.name)" : "Expand \(sub.name)")
      .accessibilityIdentifier("channels.subredditRow.\(sub.id.uuidString).toggle")
      .padding(10)

      if isExpanded {
        VStack(alignment: .leading, spacing: 10) {
          Divider()

          Text("PRESETS")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .tracking(0.3)

          presetChips

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
          peakDayChips

          HStack(spacing: 4) {
            Text("PEAK HOURS (local — \(TimeZone.current.abbreviation() ?? TimeZone.current.identifier))")
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(.secondary)
              .tracking(0.3)
            if showsSuggested {
              Text("(suggested)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
          }
          peakHourChips

          Text("EVENT SOURCES")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .tracking(0.3)
          eventSourceChips

          Text("POSTING CHECKLIST")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .tracking(0.3)

          TextEditor(text: postingChecklistBinding)
            .font(.system(size: 11))
            .frame(minHeight: 58)
            .scrollContentBackground(.hidden)
            .padding(7)
            .inputFieldStyle(cornerRadius: 6)
            .accessibilityLabel("Posting checklist for \(sub.name)")
            .accessibilityIdentifier("channels.subredditRow.\(sub.id.uuidString).postingChecklist")

          HStack {
            Spacer()
            if hasOverride {
              Button("Reset to defaults", action: resetDefaults)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .underline()
                .buttonStyle(.plain)
                .accessibilityLabel("Reset \(sub.name) defaults")
                .accessibilityIdentifier("channels.subredditRow.\(sub.id.uuidString).resetDefaults")
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
      }
    }
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.separator, lineWidth: 0.5)
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel(sub.name)
    .accessibilityIdentifier("channels.subredditRow.\(sub.id.uuidString)")
  }

  private var peakDayChips: some View {
    HStack(spacing: 4) {
      ForEach(Array(zip(SubredditPeakSelection.allDays, SubredditPeakSelection.dayKeys)), id: \.0) {
        display, key in
        let isOn = effectivePeakDays.contains(key)
        Button(action: { toggleDay(key) }) {
          Text(display)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              isOn ? AppColors.redditOrange.opacity(showsSuggested ? 0.04 : (hasOverride ? 0.12 : 0.06)) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
              RoundedRectangle(cornerRadius: 5)
                .stroke(
                  isOn ? AppColors.redditOrange : Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .foregroundStyle(isOn ? AppColors.redditOrange : .secondary)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func toggleDay(_ day: String) {
    if showsSuggested {
      let suggested = SubredditPeakSelection.suggestedDefaults()
      sub.peakDaysOverride = SubredditPeakSelection.toggledDay(day, in: suggested.days)
      sub.peakHoursUtcOverride = suggested.utcHours
    } else {
      sub.peakDaysOverride = SubredditPeakSelection.toggledDay(day, in: sub.peakDaysOverride)
      if sub.peakDaysOverride == nil {
        sub.peakHoursUtcOverride = nil
      }
    }
  }

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
            .background(isOn ? Color.green.opacity(showsSuggested ? 0.04 : (hasOverride ? 0.12 : 0.06)) : Color.clear)
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


  private var eventSourceChips: some View {
    HStack(spacing: 6) {
      sourceChip(label: "Manual", count: eventSourceSummary.manualCount, color: .secondary)
      sourceChip(
        label: "Auto", count: eventSourceSummary.generatedCount, color: AppColors.redditOrange)
    }
  }

  private func sourceChip(label: String, count: Int, color: Color) -> some View {
    Text("\(count) \(label.lowercased())")
      .font(.system(size: 10, weight: .medium))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(count > 0 ? color.opacity(0.10) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .overlay(
        RoundedRectangle(cornerRadius: 5)
          .stroke(count > 0 ? color : Color(NSColor.separatorColor), lineWidth: 0.5)
      )
      .foregroundStyle(count > 0 ? color : .secondary)
  }

  private func resetDefaults() {
    sub.peakDaysOverride = nil
    sub.peakHoursUtcOverride = nil
  }
}
