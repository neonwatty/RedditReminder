import Testing
@testable import RedditReminder

@Test @MainActor func urgencyBoundaryAtExactlyZero() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0.0) == .active)
}

@Test @MainActor func urgencyBoundaryAtHalfHour() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0.5) == .high)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 0.49) == .active)
}

@Test @MainActor func urgencyBoundaryAtTwoHours() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 2.0) == .medium)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 1.99) == .high)
}

@Test @MainActor func urgencyBoundaryAtTwelveHours() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 12.0) == .low)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 11.99) == .medium)
}

@Test @MainActor func urgencyBoundaryAtTwentyFourHours() {
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 24.0) == .none)
    #expect(TimingEngine.urgencyLevel(hoursUntilWindow: 23.99) == .low)
}
