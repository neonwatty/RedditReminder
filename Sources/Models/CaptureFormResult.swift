import Foundation

struct CaptureFormResult {
    let text: String
    let notes: String?
    let links: [String]
    let project: Project?
    let subreddits: [Subreddit]
    let mediaURLs: [URL]
}
