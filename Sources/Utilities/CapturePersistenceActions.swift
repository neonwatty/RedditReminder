import Foundation
import SwiftData

@MainActor
enum CapturePersistenceActions {
  @discardableResult
  static func saveCapture(
    _ result: CaptureFormResult,
    modelContext: ModelContext,
    mediaStore: MediaStore,
    onAppStateChanged: AppRefreshAction = {}
  ) -> Bool {
    let capture = Capture(
      title: result.title,
      text: result.text,
      notes: result.notes,
      links: result.links,
      mediaRefs: [],
      project: result.project,
      subreddits: result.subreddits
    )
    modelContext.insert(capture)

    do {
      capture.mediaRefs = try saveMediaFiles(
        result.mediaURLs, captureId: capture.id, mediaStore: mediaStore)
      try modelContext.save()
      onAppStateChanged()
      return true
    } catch {
      mediaStore.deleteAll(captureId: capture.id)
      modelContext.delete(capture)
      NSLog("RedditReminder: save failed: \(error)")
      return false
    }
  }

  @discardableResult
  static func updateCapture(
    _ capture: Capture,
    with result: CaptureFormResult,
    modelContext: ModelContext,
    mediaStore: MediaStore,
    onAppStateChanged: AppRefreshAction = {}
  ) -> Bool {
    var newlySavedRefs: [String] = []
    if !result.mediaURLs.isEmpty {
      do {
        newlySavedRefs = try saveMediaFiles(
          result.mediaURLs, captureId: capture.id, mediaStore: mediaStore)
      } catch {
        NSLog("RedditReminder: media update failed: \(error)")
        return false
      }
    }

    capture.title = result.title
    capture.text = result.text
    capture.notes = result.notes
    capture.links = result.links

    let removedRefs = Set(result.removedMediaRefs)
    if !removedRefs.isEmpty {
      capture.mediaRefs.removeAll { removedRefs.contains($0) }
    }

    capture.mediaRefs.append(contentsOf: newlySavedRefs)
    capture.project = result.project
    capture.subreddits = result.subreddits

    do {
      try modelContext.save()
      deleteMediaRefs(Array(removedRefs), captureId: capture.id, mediaStore: mediaStore)
      onAppStateChanged()
      return true
    } catch {
      NSLog("RedditReminder: update failed: \(error)")
      deleteMediaRefs(newlySavedRefs, captureId: capture.id, mediaStore: mediaStore)
      modelContext.rollback()
      return false
    }
  }

  static func deleteCapture(
    _ capture: Capture,
    modelContext: ModelContext,
    mediaStore: MediaStore,
    onAppStateChanged: AppRefreshAction = {}
  ) throws {
    let captureId = capture.id
    modelContext.delete(capture)

    do {
      try modelContext.save()
    } catch {
      NSLog("RedditReminder: delete failed: \(error)")
      modelContext.rollback()
      throw error
    }

    mediaStore.deleteAll(captureId: captureId)
    onAppStateChanged()
  }

  static func saveMediaFiles(_ urls: [URL], captureId: UUID, mediaStore: MediaStore) throws
    -> [String]
  {
    var refs: [String] = []
    do {
      for url in urls {
        refs.append(try mediaStore.saveFile(at: url, captureId: captureId))
      }
      return refs
    } catch {
      deleteMediaRefs(refs, captureId: captureId, mediaStore: mediaStore)
      throw error
    }
  }

  private static func deleteMediaRefs(_ refs: [String], captureId: UUID, mediaStore: MediaStore) {
    for ref in refs {
      mediaStore.delete(captureId: captureId, ref: ref)
    }
  }
}
