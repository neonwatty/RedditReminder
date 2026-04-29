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
        removedRefs: inout [String],
        originalRefs: [String] = []
    ) {
        removedRefs.removeAll { $0 == ref }
        if !existingRefs.contains(ref) {
            insertRestoredRef(ref, into: &existingRefs, originalRefs: originalRefs)
        }
    }

    private static func insertRestoredRef(
        _ ref: String,
        into existingRefs: inout [String],
        originalRefs: [String]
    ) {
        guard let originalIndex = originalRefs.firstIndex(of: ref) else {
            existingRefs.append(ref)
            return
        }
        let insertionIndex = existingRefs.firstIndex { existingRef in
            guard let existingIndex = originalRefs.firstIndex(of: existingRef) else { return false }
            return existingIndex > originalIndex
        } ?? existingRefs.endIndex
        existingRefs.insert(ref, at: insertionIndex)
    }
}
