import SwiftUI
import SwiftData

struct CaptureWindowView: View {
    enum Mode {
        case create
        case edit(Capture)
    }

    let mode: Mode
    let onSave: (CaptureFormResult) -> Bool
    let onCancel: () -> Void

    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]

    @State private var text: String = ""
    @State private var notes: String = ""
    @State private var selectedProject: Project?
    @State private var selectedSubreddits: Set<UUID> = []
    @State private var links: [String] = []
    @State private var newLinkText: String = ""
    @State private var droppedFiles: [URL] = []
    @State private var existingMediaRefs: [String] = []
    @State private var removedMediaRefs: [String] = []
    @State private var showPreview: Bool = false
    @State private var saveError: String?
    @AppStorage(SettingsKey.defaultProjectId) private var defaultProjectId: String = ""
    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    fieldSection("CAPTURE TEXT") {
                        VStack(spacing: 6) {
                            HStack {
                                Spacer()
                                HStack(spacing: 2) {
                                    Button(action: { showPreview = false }) {
                                        Text("Edit")
                                            .font(.system(size: 9, weight: showPreview ? .medium : .semibold))
                                            .foregroundStyle(showPreview ? .secondary : AppColors.redditOrange)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(showPreview ? Color.clear : AppColors.redditOrange.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: { showPreview = true }) {
                                        Text("Preview")
                                            .font(.system(size: 9, weight: showPreview ? .semibold : .medium))
                                            .foregroundStyle(showPreview ? AppColors.redditOrange : .secondary)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(showPreview ? AppColors.redditOrange.opacity(0.1) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if showPreview {
                                MarkdownPreviewView(text: text)
                                    .frame(minHeight: 72)
                            } else {
                                TextEditor(text: $text)
                                    .font(.system(size: 12))
                                    .frame(minHeight: 72)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .inputFieldStyle()
                            }
                        }
                    }

                    fieldSection("SUBREDDIT") {
                        CaptureSubredditPicker(
                            subreddits: subreddits,
                            selectedSubreddits: $selectedSubreddits
                        )
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
                    }

                    fieldSection("NOTES", optional: true) {
                        TextField("Add context or reminders...", text: $notes)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .inputFieldStyle()
                    }

                    fieldSection("LINKS") {
                        CaptureLinksSection(links: $links, newLinkText: $newLinkText)
                    }

                    fieldSection("MEDIA") {
                        CaptureMediaSection(
                            droppedFiles: $droppedFiles,
                            captureId: editCaptureId,
                            existingRefs: $existingMediaRefs,
                            removedRefs: $removedMediaRefs
                        )
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.system(size: 11)).foregroundStyle(.red).accessibilityIdentifier("capture-save-error")
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 420, height: 480)
        .onAppear { populateFromMode() }
    }

    private var titleBar: some View {
        HStack {
            Text(titleText)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button("Cancel", action: onCancel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

            Button("Save", action: save)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(canSave ? AppColors.redditOrange : AppColors.redditOrange.opacity(0.4))
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var titleText: String {
        switch mode {
        case .create: "New Capture"
        case .edit: "Edit Capture"
        }
    }

    private func fieldSection<Content: View>(
        _ label: String,
        optional: Bool = false,
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
            }
            content()
        }
    }

    private var canSave: Bool {
        CaptureHelpers.canSave(text: text, selectedSubredditCount: selectedSubreddits.count)
    }
    private func save() {
        guard canSave else { return }
        let selectedSubs = subreddits.filter { selectedSubreddits.contains($0.id) }
        saveError = nil
        let didSave = onSave(CaptureFormResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes, links: links,
            project: selectedProject,
            subreddits: selectedSubs,
            mediaURLs: droppedFiles,
            removedMediaRefs: removedMediaRefs
        ))
        if !didSave {
            saveError = "Save failed. Check selected media files and try again."
        }
    }

    private var editCaptureId: UUID? {
        if case .edit(let capture) = mode { return capture.id }
        return nil
    }

    private func populateFromMode() {
        switch mode {
        case .create:
            if let uuid = UUID(uuidString: defaultProjectId) {
                selectedProject = projects.first { $0.id == uuid }
            }
        case .edit(let capture):
            text = capture.text
            notes = capture.notes ?? ""
            selectedProject = capture.project
            selectedSubreddits = Set(capture.subreddits.map(\.id))
            links = capture.links
            existingMediaRefs = capture.mediaRefs
        }
    }
}
