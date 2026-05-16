import Testing
@testable import RedditReminder

@Test func captureMediaAccessibilityDefinesStableDropZoneIdentifier() {
    #expect(CaptureMediaAccessibility.dropZone == "capture-media-drop-zone")
    #expect(CaptureMediaAccessibility.selectionError == "capture-media-selection-error")
    #expect(CaptureMediaAccessibility.browseLabel == "Browse for media")
    #expect(CaptureMediaAccessibility.browseHint == "Add image or video files to this capture.")
    #expect(
        CaptureMediaAccessibility.rejectedSelectionMessage
            == "Only image or video files can be attached."
    )
    #expect(
        CaptureMediaAccessibility.importFailureMessage
            == "Media could not be added. Try another image or video file."
    )
}

@Test func captureMediaAccessibilityNormalizesExistingRefIdentifiers() {
    #expect(
        CaptureMediaAccessibility.previewExisting(ref: "Hero Image.PNG")
            == "capture-media-preview-existing-hero-image-png"
    )
    #expect(
        CaptureMediaAccessibility.removeExisting(ref: "Hero Image.PNG")
            == "capture-media-remove-existing-hero-image-png"
    )
    #expect(
        CaptureMediaAccessibility.restoreExisting(ref: "Hero Image.PNG")
            == "capture-media-restore-existing-hero-image-png"
    )
}

@Test func captureMediaAccessibilityDefinesNewMediaIdentifiers() {
    #expect(
        CaptureMediaAccessibility.previewNew(fileName: "Draft 1.PNG")
            == "capture-media-preview-new-draft-1-png"
    )
    #expect(CaptureMediaAccessibility.removeNew(index: 2) == "capture-media-remove-new-2")
}
