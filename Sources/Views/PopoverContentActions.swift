import SwiftUI

extension PopoverContentView {
    func openNewCapture() {
        openCaptureWindow(mode: .create)
    }

    func openCaptureForEditing(_ capture: Capture) {
        openCaptureWindow(mode: .edit(capture))
    }

    func openCaptureWindow(mode: CaptureWindowView.Mode) {
        let (title, successMsg): (String, String) = switch mode {
        case .create: ("New Capture", "Draft saved")
        case .edit: ("Edit Capture", "Draft updated")
        }
        let formView = CaptureWindowView(
            mode: mode,
            onSave: { result in
                let ok: Bool = switch mode {
                case .create: saveCapture(result)
                case .edit(let capture): updateCapture(capture, with: result)
                }
                menuBarController.closeCaptureWindow()
                showToastAfterReopen(ok ? successMsg : "Save failed")
            },
            onCancel: { menuBarController.closeCaptureWindow() }
        ).modelContainer(modelContext.container)
        menuBarController.showCaptureWindow(title: title, content: formView)
    }

    func openPreferences() {
        let prefsView = PreferencesView(
            notificationService: notificationService,
            heuristicsStore: heuristicsStore
        )
            .modelContainer(modelContext.container)
        menuBarController.showPreferencesWindow(content: prefsView)
    }

    @discardableResult
    func saveCapture(_ result: CaptureFormResult) -> Bool {
        let c = Capture(text: result.text, notes: result.notes, links: result.links,
                        mediaRefs: [],
                        project: result.project, subreddits: result.subreddits)
        modelContext.insert(c)
        do {
            c.mediaRefs = try saveMediaFiles(result.mediaURLs, captureId: c.id)
            try modelContext.save()
            onCaptureChanged()
            return true
        } catch {
            mediaStore.deleteAll(captureId: c.id)
            modelContext.delete(c)
            NSLog("RedditReminder: save failed: \(error)")
            return false
        }
    }

    @discardableResult
    func updateCapture(_ capture: Capture, with r: CaptureFormResult) -> Bool {
        capture.text = r.text; capture.notes = r.notes; capture.links = r.links
        let removedRefs = Set(r.removedMediaRefs)
        if !removedRefs.isEmpty {
            capture.mediaRefs.removeAll { removedRefs.contains($0) }
        }

        var newlySavedRefs: [String] = []
        if !r.mediaURLs.isEmpty {
            do {
                for url in r.mediaURLs {
                    let ref = try mediaStore.saveFile(at: url, captureId: capture.id)
                    newlySavedRefs.append(ref)
                    capture.mediaRefs.append(ref)
                }
            } catch {
                NSLog("RedditReminder: media update failed: \(error)")
                for ref in newlySavedRefs {
                    mediaStore.delete(captureId: capture.id, ref: ref)
                }
                modelContext.rollback()
                return false
            }
        }
        capture.project = r.project
        capture.subreddits = r.subreddits
        do {
            try modelContext.save()
            for ref in removedRefs {
                mediaStore.delete(captureId: capture.id, ref: ref)
            }
            onCaptureChanged()
            return true
        } catch {
            NSLog("RedditReminder: update failed: \(error)")
            for ref in newlySavedRefs {
                mediaStore.delete(captureId: capture.id, ref: ref)
            }
            modelContext.rollback()
            return false
        }
    }

    func markCaptureAsPosted(_ capture: Capture) {
        capture.markAsPosted()
        do { try modelContext.save() } catch {
            NSLog("RedditReminder: mark posted failed: \(error)")
            modelContext.rollback()
            showToastAfterReopen("Failed to mark as posted")
            return
        }
        onCaptureChanged()
        showToastAfterReopen("Marked as posted")
    }

    func restoreCaptureToQueue(_ capture: Capture) {
        capture.markAsQueued()
        do { try modelContext.save() } catch {
            NSLog("RedditReminder: restore queued failed: \(error)")
            modelContext.rollback()
            showToastAfterReopen("Restore failed")
            return
        }
        onCaptureChanged()
        showToastAfterReopen("Moved back to queue")
    }

    func deleteCapture(_ capture: Capture) {
        let captureId = capture.id
        modelContext.delete(capture)
        do { try modelContext.save() } catch {
            NSLog("RedditReminder: delete failed: \(error)")
            modelContext.rollback()
            showToastAfterReopen("Delete failed")
            return
        }
        mediaStore.deleteAll(captureId: captureId)
        onCaptureChanged()
        showToastAfterReopen("Capture deleted")
    }

    func saveMediaFiles(_ urls: [URL], captureId: UUID) throws -> [String] {
        var refs: [String] = []
        do {
            for url in urls {
                refs.append(try mediaStore.saveFile(at: url, captureId: captureId))
            }
            return refs
        } catch {
            for ref in refs {
                mediaStore.delete(captureId: captureId, ref: ref)
            }
            throw error
        }
    }

    func showToastAfterReopen(_ message: String) {
        toastTask?.cancel()
        menuBarController.openPopover()
        toastTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { toastMessage = message }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { toastMessage = nil }
        }
    }
}
