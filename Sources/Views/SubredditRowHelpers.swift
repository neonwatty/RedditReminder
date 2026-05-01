import SwiftData
import SwiftUI

extension SubredditRow {
  func toggleHourLocal(_ localHour: Int) {
    let utcHour = SubredditPeakSelection.localHourToUtc(localHour)
    if showsSuggested {
      let suggested = SubredditPeakSelection.suggestedDefaults()
      sub.peakDaysOverride = suggested.days
      sub.peakHoursUtcOverride = SubredditPeakSelection.toggledHour(utcHour, in: suggested.utcHours)
    } else {
      sub.peakHoursUtcOverride = SubredditPeakSelection.toggledHour(utcHour, in: sub.peakHoursUtcOverride)
    }
  }

  func applyPreset(_ preset: SubredditPeakSelection.PeakPreset) {
    let applied = SubredditPeakSelection.applyPreset(preset)
    sub.peakDaysOverride = applied.days
    sub.peakHoursUtcOverride = applied.utcHours
  }

  var peakDaysSummaryText: String {
    SubredditPeakSelection.peakDaysSummary(
      effectivePeakDays: effectivePeakDays, hasOverride: hasOverride)
  }

  var hasOverride: Bool {
    SubredditPeakSelection.hasOverride(days: sub.peakDaysOverride, hours: sub.peakHoursUtcOverride)
  }

  var showsSuggested: Bool {
    SubredditPeakSelection.needsSuggestedDefaults(
      daysOverride: sub.peakDaysOverride,
      hoursOverride: sub.peakHoursUtcOverride,
      peakInfo: peakInfo
    )
  }

  var effectivePeakDays: [String] {
    if showsSuggested {
      return SubredditPeakSelection.suggestedDefaults().days
    }
    return SubredditPeakSelection.effectivePeakDays(override: sub.peakDaysOverride, peakInfo: peakInfo)
  }

  var effectivePeakHours: [Int] {
    if showsSuggested {
      return SubredditPeakSelection.suggestedDefaults().utcHours
    }
    return SubredditPeakSelection.effectivePeakHours(
      override: sub.peakHoursUtcOverride, peakInfo: peakInfo)
  }

  var effectivePeakHoursLocal: [Int] {
    if showsSuggested {
      return SubredditPeakSelection.suggestedDefaults().localHours
    }
    return SubredditPeakSelection.utcHoursToLocal(effectivePeakHours)
  }

  var eventSourceSummary: EventSourceSummary {
    EventSourceSummary.active(events: sub.events)
  }

  var hasPostingChecklist: Bool {
    !(sub.postingChecklist?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
  }

  var postingChecklistBinding: Binding<String> {
    Binding(
      get: { sub.postingChecklist ?? "" },
      set: { newValue in
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        sub.postingChecklist = trimmed.isEmpty ? nil : newValue
      }
    )
  }
}

struct SubredditDropDelegate: DropDelegate {
  let target: Subreddit
  @Binding var dragging: Subreddit?
  let subreddits: [Subreddit]
  let modelContext: ModelContext

  func performDrop(info: DropInfo) -> Bool {
    dragging = nil
    return true
  }

  func dropEntered(info: DropInfo) {
    guard let source = dragging, source.id != target.id else { return }
    SubredditPersistenceActions.reorder(
      source: source,
      target: target,
      subreddits: subreddits,
      modelContext: modelContext
    )
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }
}
