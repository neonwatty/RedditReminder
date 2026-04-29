import Foundation

extension BackupService {
    func mediaFiles(from captures: [Capture], mediaStore: MediaStore?) throws -> [BackupMediaFile]? {
        guard let mediaStore else { return nil }
        var files: [BackupMediaFile] = []
        for capture in captures {
            for ref in capture.mediaRefs {
                guard let data = try mediaStore.loadData(captureId: capture.id, ref: ref) else { continue }
                files.append(BackupMediaFile(captureId: capture.id, ref: ref, data: data))
            }
        }
        return files
    }

    func restoreEmbeddedMedia(from backup: AppBackup, mediaStore: MediaStore?) throws -> Set<MediaIdentity> {
        guard let mediaStore, let mediaFiles = backup.mediaFiles else { return [] }
        var restored: Set<MediaIdentity> = []
        do {
            for file in mediaFiles {
                try mediaStore.saveData(file.data, captureId: file.captureId, ref: file.ref)
                restored.insert(MediaIdentity(captureId: file.captureId, ref: file.ref))
            }
            return restored
        } catch {
            deleteMedia(restored, mediaStore: mediaStore)
            throw error
        }
    }

    func deleteMedia(_ files: Set<MediaIdentity>, mediaStore: MediaStore?) {
        guard let mediaStore else { return }
        for file in files {
            mediaStore.delete(captureId: file.captureId, ref: file.ref)
        }
    }

    func restoredMediaRefs(
        from capture: BackupCapture,
        mediaStore: MediaStore?,
        restoredMedia: Set<MediaIdentity>
    ) -> [String] {
        guard let mediaStore else { return capture.mediaRefs }
        return capture.mediaRefs.filter { ref in
            restoredMedia.contains(MediaIdentity(captureId: capture.id, ref: ref)) ||
                mediaStore.exists(captureId: capture.id, ref: ref)
        }
    }
}

struct MediaIdentity: Hashable {
    let captureId: UUID
    let ref: String
}
