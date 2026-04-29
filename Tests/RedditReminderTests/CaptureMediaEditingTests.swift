import Testing
@testable import RedditReminder

@Test func captureMediaEditingMovesExistingRefToRemovedRefs() {
    var existingRefs = ["first.png", "second.png"]
    var removedRefs: [String] = []

    CaptureMediaEditing.removeExisting(
        ref: "first.png",
        existingRefs: &existingRefs,
        removedRefs: &removedRefs
    )

    #expect(existingRefs == ["second.png"])
    #expect(removedRefs == ["first.png"])
}

@Test func captureMediaEditingDoesNotDuplicateRemovedRefs() {
    var existingRefs = ["second.png"]
    var removedRefs = ["first.png"]

    CaptureMediaEditing.removeExisting(
        ref: "first.png",
        existingRefs: &existingRefs,
        removedRefs: &removedRefs
    )

    #expect(existingRefs == ["second.png"])
    #expect(removedRefs == ["first.png"])
}

@Test func captureMediaEditingRestoresRemovedRef() {
    var existingRefs = ["second.png"]
    var removedRefs = ["first.png"]

    CaptureMediaEditing.restoreExisting(
        ref: "first.png",
        existingRefs: &existingRefs,
        removedRefs: &removedRefs
    )

    #expect(existingRefs == ["second.png", "first.png"])
    #expect(removedRefs.isEmpty)
}

@Test func captureMediaEditingDoesNotDuplicateRestoredRefs() {
    var existingRefs = ["first.png", "second.png"]
    var removedRefs = ["first.png"]

    CaptureMediaEditing.restoreExisting(
        ref: "first.png",
        existingRefs: &existingRefs,
        removedRefs: &removedRefs
    )

    #expect(existingRefs == ["first.png", "second.png"])
    #expect(removedRefs.isEmpty)
}
