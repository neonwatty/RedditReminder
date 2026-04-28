import Foundation

extension BackupProject {
    init(project: Project) {
        self.init(
            id: project.id,
            name: project.name,
            projectDescription: project.projectDescription,
            color: project.color,
            archived: project.archived,
            createdAt: project.createdAt
        )
    }
}

extension BackupSubreddit {
    init(subreddit: Subreddit) {
        self.init(
            id: subreddit.id,
            name: subreddit.name,
            sortOrder: subreddit.sortOrder,
            peakDaysOverride: subreddit.peakDaysOverride,
            peakHoursUtcOverride: subreddit.peakHoursUtcOverride
        )
    }
}

extension BackupSubredditEvent {
    init(event: SubredditEvent) {
        self.init(
            id: event.id,
            name: event.name,
            subredditId: event.subreddit?.id,
            rrule: event.rrule,
            oneOffDate: event.oneOffDate,
            recurrenceHour: event.recurrenceHour,
            recurrenceMinute: event.recurrenceMinute,
            recurrenceTimeZoneIdentifier: event.recurrenceTimeZoneIdentifier,
            reminderLeadMinutes: event.reminderLeadMinutes,
            isActive: event.isActive,
            isGeneratedFromHeuristics: event.isGeneratedFromHeuristics,
            generationKey: event.generationKey
        )
    }
}

extension BackupCapture {
    init(capture: Capture) {
        self.init(
            id: capture.id,
            text: capture.text,
            notes: capture.notes,
            links: capture.links,
            mediaRefs: capture.mediaRefs,
            status: capture.status,
            createdAt: capture.createdAt,
            postedAt: capture.postedAt,
            projectId: capture.project?.id,
            subredditIds: capture.subreddits.map(\.id)
        )
    }
}
