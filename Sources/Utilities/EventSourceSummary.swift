struct EventSourceSummary: Equatable {
    let manualCount: Int
    let generatedCount: Int

    var hasEvents: Bool {
        manualCount > 0 || generatedCount > 0
    }

    var compactLabel: String {
        guard hasEvents else { return "no events" }
        return [
            manualCount > 0 ? "\(manualCount) manual" : nil,
            generatedCount > 0 ? "\(generatedCount) auto" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    static func active(events: [SubredditEvent]) -> EventSourceSummary {
        EventSourceSummary(
            manualCount: events.filter { $0.isActive && !$0.isGeneratedFromHeuristics }.count,
            generatedCount: events.filter { $0.isActive && $0.isGeneratedFromHeuristics }.count
        )
    }
}
