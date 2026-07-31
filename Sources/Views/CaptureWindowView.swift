import SwiftData
import SwiftUI

struct CaptureWindowView: View {
  enum Mode {
    case create
    case edit(Capture)
  }

  static let saveRequirementsAccessibilityIdentifier = "captureWindow.saveRequirements"
  static let contentRequirementText = "Add a title or capture text to save."

  let mode: Mode
  var initialDraft: CaptureFormDraft?
  let onSave: (CaptureFormResult) -> Bool
  let onCancel: (CaptureFormDraft) -> Void
  var onAddSubreddit: (CaptureFormDraft) -> Void = { _ in }
  var onDraftChanged: (CaptureFormDraft) -> Void = { _ in }

  @Query(sort: \Project.name) var projects: [Project]
  @Query(sort: \Subreddit.sortOrder) var subreddits: [Subreddit]

  @State var title: String = ""
  @State var text: String = ""
  @State var notes: String = ""
  @State var selectedProject: Project?
  @State var selectedSubreddits: Set<UUID> = []
  @State var links: [String] = []
  @State var newLinkText: String = ""
  @State var droppedFiles: [URL] = []
  @State var existingMediaRefs: [String] = []
  @State var removedMediaRefs: [String] = []
  @State var originalMediaRefs: [String] = []
  @State var showPreview: Bool = false
  @State var saveError: String?
  @AppStorage(SettingsKey.defaultProjectId) var defaultProjectId: String = ""
  var body: some View {
    VStack(spacing: 0) {
      titleBar
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          fieldSection("TITLE") {
            TextField("Add a Reddit post title...", text: $title)
              .font(.system(size: 12))
              .textFieldStyle(.plain)
              .padding(8)
              .inputFieldStyle()
              .accessibilityLabel("Capture title")
              .accessibilityIdentifier("captureWindow.title")
          }

          fieldSection("CAPTURE TEXT") {
            VStack(spacing: 6) {
              HStack {
                Spacer()
                Picker("Capture text mode", selection: $showPreview) {
                  Text("Edit")
                    .tag(false)
                    .accessibilityLabel("Edit capture text")
                    .accessibilityIdentifier("captureWindow.text.edit")
                  Text("Preview")
                    .tag(true)
                    .accessibilityLabel("Preview capture text")
                    .accessibilityIdentifier("captureWindow.text.preview")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 128)
                .accessibilityIdentifier("captureWindow.text.mode")
              }
              if showPreview {
                MarkdownPreviewView(text: text)
                  .frame(minHeight: 72)
                  .accessibilityIdentifier("captureWindow.text.previewContent")
              } else {
                TextEditor(text: $text)
                  .font(.system(size: 12))
                  .frame(minHeight: 72)
                  .scrollContentBackground(.hidden)
                  .padding(8)
                  .inputFieldStyle()
                  .accessibilityLabel("Capture text")
                  .accessibilityIdentifier("captureWindow.text")
              }
              Text(Self.contentRequirementText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("captureWindow.contentRequirement")
            }
          }
          fieldSection("SUBREDDIT", required: true) {
            CaptureSubredditPicker(
              subreddits: subreddits,
              selectedSubreddits: $selectedSubreddits,
              onAddSubreddit: addSubredditFromPicker
            )

            if let saveRequirementsMessage, selectedSubreddits.isEmpty {
              Text(saveRequirementsMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(Self.saveRequirementsAccessibilityIdentifier)
            }
          }

          fieldSection("PROJECT", optional: true) {
            Picker("", selection: $selectedProject) {
              Text("None").tag(nil as Project?)
              ForEach(projects.filter { !$0.archived }, id: \.id) { project in
                Text(project.name).tag(project as Project?)
              }
            }
            .labelsHidden()
            .font(.system(size: 12))
            .padding(4)
            .inputFieldStyle()
            .accessibilityLabel("Capture project")
            .accessibilityIdentifier("captureWindow.project")
          }

          fieldSection("NOTES", optional: true) {
            TextEditor(text: $notes)
              .font(.system(size: 12))
              .frame(minHeight: 64)
              .scrollContentBackground(.hidden)
              .padding(8)
              .inputFieldStyle()
              .accessibilityLabel("Capture notes")
              .accessibilityIdentifier("captureWindow.notes")
          }

          fieldSection("LINKS") {
            CaptureLinksSection(links: $links, newLinkText: $newLinkText)
          }

          fieldSection("MEDIA") {
            CaptureMediaSection(
              droppedFiles: $droppedFiles,
              captureId: editCaptureId,
              existingRefs: $existingMediaRefs,
              removedRefs: $removedMediaRefs,
              originalRefs: originalMediaRefs
            )
          }

          if let saveRequirementsMessage, !selectedSubreddits.isEmpty {
            Text(saveRequirementsMessage)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .accessibilityIdentifier(Self.saveRequirementsAccessibilityIdentifier)
          }

          if let saveError {
            Text(saveError)
              .font(.system(size: 11)).foregroundStyle(.red).accessibilityIdentifier(
                "capture-save-error")
          }
        }
        .padding(16)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      populateFromMode()
      onDraftChanged(currentDraft)
    }
    .onChange(of: currentDraft) {
      onDraftChanged(currentDraft)
    }
  }

}
