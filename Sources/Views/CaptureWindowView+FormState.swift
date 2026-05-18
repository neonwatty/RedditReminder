import SwiftUI

extension CaptureWindowView {
  var titleBar: some View {
    HStack {
      Text(titleText)
        .font(.system(size: 13, weight: .semibold))

      Spacer()

      Button("Cancel") { onCancel(currentDraft) }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel capture")
        .accessibilityIdentifier("captureWindow.cancel")

      Button("Save", action: save)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(canSave ? AppColors.redditOrange : AppColors.redditOrange.opacity(0.4))
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.leading, 6)
        .accessibilityLabel("Save capture")
        .accessibilityIdentifier("captureWindow.save")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  var titleText: String {
    switch mode {
    case .create: "New Capture"
    case .edit: "Edit Capture"
    }
  }

  func fieldSection<Content: View>(
    _ label: String,
    optional: Bool = false,
    required: Bool = false,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 4) {
        Text(label)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
          .tracking(0.3)
        if optional {
          Text("(optional)")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
        if required {
          Text("(required)")
            .font(.system(size: 10))
            .foregroundStyle(AppColors.redditOrange)
        }
      }
      content()
    }
  }

  var canSave: Bool {
    CaptureHelpers.canSave(
      title: title,
      text: text,
      selectedSubredditCount: selectedSubreddits.count
    )
  }

  var saveRequirementsMessage: String? {
    CaptureHelpers.saveRequirementsMessage(
      title: title,
      text: text,
      selectedSubredditCount: selectedSubreddits.count
    )
  }

  var currentDraft: CaptureFormDraft {
    CaptureFormDraft(
      title: title,
      text: text,
      notes: notes,
      selectedProjectId: selectedProject?.id,
      selectedSubredditIds: selectedSubreddits,
      links: links,
      newLinkText: newLinkText,
      mediaURLs: droppedFiles
    )
  }

  var hasUnsavedEditChanges: Bool {
    guard case .edit(let capture) = mode else { return false }
    return currentDraft
      != CaptureFormDraft(
        title: capture.title ?? "",
        text: capture.text,
        notes: capture.notes ?? "",
        selectedProjectId: capture.project?.id,
        selectedSubredditIds: Set(capture.subreddits.map(\.id)),
        links: capture.links
      )
  }

  func addSubredditFromPicker() {
    if hasUnsavedEditChanges {
      saveError = "Save or cancel this edit before adding a channel."
      return
    }

    onAddSubreddit(currentDraft)
  }

  func save() {
    guard canSave else { return }
    let selectedSubs = subreddits.filter { selectedSubreddits.contains($0.id) }
    saveError = nil
    let didSave = onSave(
      CaptureFormResult(
        title: title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        text: text.trimmingCharacters(in: .whitespacesAndNewlines),
        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        links: links,
        project: selectedProject,
        subreddits: selectedSubs,
        mediaURLs: droppedFiles,
        removedMediaRefs: removedMediaRefs
      ))
    if !didSave {
      saveError = "Save failed. Check selected media files and try again."
    }
  }

  var editCaptureId: UUID? {
    if case .edit(let capture) = mode { return capture.id }
    return nil
  }

  func populateFromMode() {
    switch mode {
    case .create:
      if let initialDraft {
        title = initialDraft.title
        text = initialDraft.text
        notes = initialDraft.notes
        selectedProject = projects.first { $0.id == initialDraft.selectedProjectId }
        selectedSubreddits = initialDraft.selectedSubredditIds
        links = initialDraft.links
        newLinkText = initialDraft.newLinkText
        droppedFiles = initialDraft.mediaURLs
      } else if let uuid = UUID(uuidString: defaultProjectId) {
        selectedProject = projects.first { $0.id == uuid }
      }
    case .edit(let capture):
      title = capture.title ?? ""
      text = capture.text
      notes = capture.notes ?? ""
      selectedProject = capture.project
      selectedSubreddits = Set(capture.subreddits.map(\.id))
      links = capture.links
      existingMediaRefs = capture.mediaRefs
      originalMediaRefs = capture.mediaRefs
    }
  }
}

extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
