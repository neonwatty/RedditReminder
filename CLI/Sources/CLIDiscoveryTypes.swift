import Foundation

struct SearchInput {
  let query: String
  let limit: Int
}

struct ContextInput {
  let limit: Int
}

struct SearchResultDTO: Encodable {
  let kind: String
  let id: String
  let title: String
  let subtitle: String?
}

struct ContextDTO: Encodable {
  let generatedAt: String
  let counts: ContextCountsDTO
  let projects: [ProjectDTO]
  let subreddits: [SubredditDTO]
  let queuedCaptures: [CaptureDTO]
  let upcomingEvents: [EventDTO]
  let peakPresets: [PeakPresetDTO]
}

struct ContextCountsDTO: Encodable {
  let capturesQueued: Int
  let capturesPosted: Int
  let projectsActive: Int
  let projectsArchived: Int
  let subreddits: Int
  let eventsActive: Int
}
