import Foundation

struct CaptureFormResult {
    let text: String
    let notes: String?
    let links: [String]
    let project: Project?
    let subreddits: [Subreddit]
    let mediaURLs: [URL]
    let removedMediaRefs: [String]

    init(
        text: String,
        notes: String?,
        links: [String],
        project: Project?,
        subreddits: [Subreddit],
        mediaURLs: [URL],
        removedMediaRefs: [String] = []
    ) {
        self.text = text
        self.notes = notes
        self.links = links
        self.project = project
        self.subreddits = subreddits
        self.mediaURLs = mediaURLs
        self.removedMediaRefs = removedMediaRefs
    }
}
