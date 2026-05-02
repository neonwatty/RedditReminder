import Foundation

enum CLIResponseData: Encodable {
  case captures([CaptureDTO])
  case projects([ProjectDTO])
  case project(ProjectDTO)
  case subreddits([SubredditDTO])
  case subreddit(SubredditDTO)
  case peakPresets([PeakPresetDTO])
  case peakInfo(PeakInfoDTO)
  case dryRun(String)

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .captures(let value): try container.encode(value)
    case .projects(let value): try container.encode(value)
    case .project(let value): try container.encode(value)
    case .subreddits(let value): try container.encode(value)
    case .subreddit(let value): try container.encode(value)
    case .peakPresets(let value): try container.encode(value)
    case .peakInfo(let value): try container.encode(value)
    case .dryRun(let value): try container.encode(["message": value])
    }
  }
}

struct CLIResponse: Encodable {
  let ok: Bool
  let data: CLIResponseData?
  let warnings: [String]
  let errors: [String]

  static func success(data: CLIResponseData, warnings: [String] = []) -> CLIResponse {
    CLIResponse(ok: true, data: data, warnings: warnings, errors: [])
  }
}

struct CaptureDTO: Encodable {
  let id: String
  let title: String?
  let text: String
  let notes: String?
  let links: [String]
  let mediaRefs: [String]
  let status: String
  let createdAt: String
  let postedAt: String?
  let postedURL: String?
  let project: ProjectRefDTO?
  let subreddits: [SubredditRefDTO]

  init(_ capture: Capture) {
    id = capture.id.uuidString
    title = capture.title
    text = capture.text
    notes = capture.notes
    links = capture.links
    mediaRefs = capture.mediaRefs
    status = capture.status.rawValue
    createdAt = CLIFormat.date(capture.createdAt)
    postedAt = capture.postedAt.map(CLIFormat.date)
    postedURL = capture.postedURL
    project = capture.project.map(ProjectRefDTO.init)
    subreddits = capture.subreddits.sorted { $0.sortOrder < $1.sortOrder }.map(SubredditRefDTO.init)
  }
}

struct ProjectDTO: Encodable {
  let id: String
  let name: String
  let description: String?
  let color: String?
  let archived: Bool
  let createdAt: String

  init(_ project: Project) {
    id = project.id.uuidString
    name = project.name
    description = project.projectDescription
    color = project.color
    archived = project.archived
    createdAt = CLIFormat.date(project.createdAt)
  }
}

struct ProjectRefDTO: Encodable {
  let id: String
  let name: String

  init(_ project: Project) {
    id = project.id.uuidString
    name = project.name
  }
}

struct SubredditDTO: Encodable {
  let id: String
  let name: String
  let sortOrder: Int
  let postingChecklist: String?
  let peak: PeakSummaryDTO

  init(_ subreddit: Subreddit, peakInfo: PeakInfo?) {
    id = subreddit.id.uuidString
    name = subreddit.name
    sortOrder = subreddit.sortOrder
    postingChecklist = subreddit.postingChecklist
    peak = PeakSummaryDTO(subreddit: subreddit, peakInfo: peakInfo)
  }
}

struct SubredditRefDTO: Encodable {
  let id: String
  let name: String

  init(_ subreddit: Subreddit) {
    id = subreddit.id.uuidString
    name = subreddit.name
  }
}

struct PeakPresetDTO: Encodable {
  let label: String
  let days: [String]
  let localHours: [Int]

  init(_ preset: SubredditPeakSelection.PeakPreset) {
    label = preset.label
    days = preset.days
    localHours = preset.localHours
  }
}

struct PeakSummaryDTO: Encodable {
  let source: String
  let days: [String]
  let hoursUtc: [Int]
  let hoursLocal: [Int]

  init(subreddit: Subreddit, peakInfo: PeakInfo?) {
    if subreddit.peakDaysOverride != nil || subreddit.peakHoursUtcOverride != nil {
      source = "override"
    } else if peakInfo != nil {
      source = "bundled"
    } else {
      source = "none"
    }
    days = peakInfo?.peakDays ?? []
    hoursUtc = peakInfo?.peakHoursUtc ?? []
    hoursLocal = SubredditPeakSelection.utcHoursToLocal(hoursUtc)
  }
}

struct PeakInfoDTO: Encodable {
  let subreddit: SubredditRefDTO
  let peak: PeakSummaryDTO

  init(subreddit: Subreddit, peakInfo: PeakInfo?) {
    self.subreddit = SubredditRefDTO(subreddit)
    peak = PeakSummaryDTO(subreddit: subreddit, peakInfo: peakInfo)
  }
}
