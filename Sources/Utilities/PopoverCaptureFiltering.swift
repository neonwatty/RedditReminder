import Foundation

enum PopoverCaptureFiltering {
    static func queuedCaptures(from captures: [Capture]) -> [Capture] {
        captures.filter { $0.status == .queued }
    }

    static func postedCaptures(from captures: [Capture]) -> [Capture] {
        captures.filter { $0.status == .posted }
    }

    static func displayedQueuedCaptures(
        from captures: [Capture],
        filterSubredditId: UUID?,
        searchText: String
    ) -> [Capture] {
        let queued = queuedCaptures(from: captures)
        let subredditFiltered: [Capture]
        if let filterSubredditId {
            subredditFiltered = queued.filter { capture in
                capture.subreddits.contains { $0.id == filterSubredditId }
            }
        } else {
            subredditFiltered = queued
        }
        return subredditFiltered.filter { CaptureHelpers.matchesSearch($0, query: searchText) }
    }

    static func displayedPostedCaptures(from captures: [Capture], searchText: String) -> [Capture] {
        postedCaptures(from: captures).filter { CaptureHelpers.matchesSearch($0, query: searchText) }
    }
}
