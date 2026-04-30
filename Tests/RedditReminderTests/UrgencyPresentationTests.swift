import Testing

@testable import RedditReminder

@Test func urgencyPresentationLabelsUserFacingStates() {
  #expect(UrgencyPresentation.label(for: .active) == "Posting window is active")
  #expect(UrgencyPresentation.label(for: .high) == "Posting window soon")
  #expect(UrgencyPresentation.label(for: .medium) == "Posting window later today")
  #expect(UrgencyPresentation.label(for: .low) == "Posting window within 24 hours")
  #expect(UrgencyPresentation.label(for: .expired) == "Posting window has passed")
  #expect(UrgencyPresentation.label(for: .none) == "No upcoming posting window")
}

@Test func urgencyPresentationShowsDotsOnlyForActionableUrgency() {
  #expect(UrgencyPresentation.color(for: .active) != nil)
  #expect(UrgencyPresentation.color(for: .high) != nil)
  #expect(UrgencyPresentation.color(for: .medium) != nil)
  #expect(UrgencyPresentation.color(for: .low) == nil)
  #expect(UrgencyPresentation.color(for: .none) == nil)
  #expect(UrgencyPresentation.color(for: .expired) == nil)
}

@Test func urgencyPresentationAccessibilityLabelIncludesLabel() {
  #expect(UrgencyPresentation.accessibilityLabel(for: .high) == "Urgency: Posting window soon")
}
