import Foundation
import SwiftData

struct PlannerEventLoadResult {
  let events: [SubredditEvent]
  let oneOffCount: Int
  let recurringCount: Int
  let limitPerKind: Int

  var loadedCount: Int { events.count }
  var hitLimit: Bool {
    oneOffCount >= limitPerKind || recurringCount >= limitPerKind
  }
}

enum PlannerEventLoader {
  static let defaultLimitPerKind = 500

  @MainActor
  static func fetchUpcomingCandidates(
    context: ModelContext,
    now: Date = Date(),
    horizonDays: Int = 7,
    limitPerKind: Int = defaultLimitPerKind
  ) throws -> PlannerEventLoadResult {
    let safeLimit = max(1, limitPerKind)
    let horizon = now.addingTimeInterval(TimeInterval(max(1, horizonDays)) * 24 * 3600)

    var oneOffDescriptor = FetchDescriptor<SubredditEvent>(
      predicate: #Predicate<SubredditEvent> { event in
        if let oneOffDate = event.oneOffDate {
          event.isActive && oneOffDate > now && oneOffDate <= horizon
        } else {
          false
        }
      },
      sortBy: [SortDescriptor(\.oneOffDate)]
    )
    oneOffDescriptor.fetchLimit = safeLimit

    var recurringDescriptor = FetchDescriptor<SubredditEvent>(
      predicate: #Predicate<SubredditEvent> { event in
        event.isActive && event.rrule != nil
      },
      sortBy: [SortDescriptor(\.name)]
    )
    recurringDescriptor.fetchLimit = safeLimit

    let oneOffs = try context.fetch(oneOffDescriptor)
    let recurring = try context.fetch(recurringDescriptor)

    return PlannerEventLoadResult(
      events: oneOffs + recurring,
      oneOffCount: oneOffs.count,
      recurringCount: recurring.count,
      limitPerKind: safeLimit
    )
  }
}
