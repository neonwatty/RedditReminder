import Foundation

struct CaptureFormResult {
  let title: String?
  let text: String
  let notes: String?
  let links: [String]
  let project: Project?
  let subreddits: [Subreddit]
  let mediaURLs: [URL]
  let removedMediaRefs: [String]

  init(
    title: String? = nil,
    text: String,
    notes: String?,
    links: [String],
    project: Project?,
    subreddits: [Subreddit],
    mediaURLs: [URL],
    removedMediaRefs: [String] = []
  ) {
    self.title = title
    self.text = text
    self.notes = notes
    self.links = links
    self.project = project
    self.subreddits = subreddits
    self.mediaURLs = mediaURLs
    self.removedMediaRefs = removedMediaRefs
  }
}

struct CaptureFormDraft: Equatable {
  var title: String = ""
  var text: String = ""
  var notes: String = ""
  var selectedProjectId: UUID?
  var selectedSubredditIds: Set<UUID> = []
  var links: [String] = []
  var newLinkText: String = ""
  var mediaURLs: [URL] = []

  var hasRecoverableContent: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !newLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !links.isEmpty
      || !mediaURLs.isEmpty
      || selectedProjectId != nil
      || !selectedSubredditIds.isEmpty
  }
}
