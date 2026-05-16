import Foundation

enum CaptureMediaAccessibility {
    static let dropZone = "capture-media-drop-zone"
    static let selectionError = "capture-media-selection-error"
    static let browseLabel = "Browse for media"
    static let browseHint = "Add image or video files to this capture."
    static let rejectedSelectionMessage = "Only image or video files can be attached."
    static let importFailureMessage = "Media could not be added. Try another image or video file."

    static func previewExisting(ref: String) -> String {
        "capture-media-preview-existing-\(token(ref))"
    }

    static func removeExisting(ref: String) -> String {
        "capture-media-remove-existing-\(token(ref))"
    }

    static func restoreExisting(ref: String) -> String {
        "capture-media-restore-existing-\(token(ref))"
    }

    static func previewNew(fileName: String) -> String {
        "capture-media-preview-new-\(token(fileName))"
    }

    static func removeNew(index: Int) -> String {
        "capture-media-remove-new-\(index)"
    }

    private static func token(_ value: String) -> String {
        value
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { partial, character in
                if character != "-" || partial.last != "-" {
                    partial.append(character)
                }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
