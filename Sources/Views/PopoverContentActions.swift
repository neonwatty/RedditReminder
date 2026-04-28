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
        CapturePersistenceActions.saveCapture(
            result,
            modelContext: modelContext,
            mediaStore: mediaStore,
            onCaptureChanged: onCaptureChanged
        )
    }

    @discardableResult
    func updateCapture(_ capture: Capture, with r: CaptureFormResult) -> Bool {
        CapturePersistenceActions.updateCapture(
            capture,
            with: r,
            modelContext: modelContext,
            mediaStore: mediaStore,
            onCaptureChanged: onCaptureChanged
        )
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
        do {
            try CapturePersistenceActions.deleteCapture(
                capture,
                modelContext: modelContext,
                mediaStore: mediaStore,
                onCaptureChanged: onCaptureChanged
            )
        } catch {
            showToastAfterReopen("Delete failed")
            return
        }
        showToastAfterReopen("Capture deleted")
    }

    func saveMediaFiles(_ urls: [URL], captureId: UUID) throws -> [String] {
        try CapturePersistenceActions.saveMediaFiles(urls, captureId: captureId, mediaStore: mediaStore)
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
