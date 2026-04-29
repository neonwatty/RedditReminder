import Foundation
import Testing
@testable import RedditReminder

@Test @MainActor func eventBannerRelativeTimeUsesInjectedReferenceDate() {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
    let eventDate = referenceDate.addingTimeInterval(2 * 3600)

    #expect(
        EventBannerView.relativeTime(
            eventDate,
            relativeTo: referenceDate,
            formatter: formatter
        ) == "in 2h"
    )
}

@Test @MainActor func eventBannerRelativeTimeHandlesPastDates() {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
    let eventDate = referenceDate.addingTimeInterval(-30 * 60)

    #expect(
        EventBannerView.relativeTime(
            eventDate,
            relativeTo: referenceDate,
            formatter: formatter
        ) == "30m ago"
    )
}
