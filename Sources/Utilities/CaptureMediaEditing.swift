import Foundation

enum CaptureMediaEditing {
    static func removeExisting(
        ref: String,
        existingRefs: inout [String],
        removedRefs: inout [String]
    ) {
        existingRefs.removeAll { $0 == ref }
        if !removedRefs.contains(ref) {
            removedRefs.append(ref)
        }
    }

    static func restoreExisting(
        ref: String,
        existingRefs: inout [String],
        removedRefs: inout [String]
    ) {
        removedRefs.removeAll { $0 == ref }
        if !existingRefs.contains(ref) {
            existingRefs.append(ref)
        }
    }
}
