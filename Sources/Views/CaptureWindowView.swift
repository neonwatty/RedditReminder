import SwiftUI
import SwiftData

struct CaptureWindowView: View {
    enum Mode {
        case create
        case edit(Capture)
    }

    let mode: Mode
    let onSave: (CaptureFormResult) -> Void
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
    @State private var isDragOver: Bool = false

    private static let redditOrange = AppColors.redditOrange

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    fieldSection("CAPTURE TEXT") {
                        TextEditor(text: $text)
                            .font(.system(size: 12))
                            .frame(minHeight: 72)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
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
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                    }

                    fieldSection("NOTES", optional: true) {
                        TextField("Add context or reminders...", text: $notes)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    }

                    fieldSection("LINKS") {
                        CaptureLinksSection(links: $links, newLinkText: $newLinkText)
                    }

                    fieldSection("MEDIA") {
                        CaptureMediaSection(droppedFiles: $droppedFiles, isDragOver: $isDragOver)
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
                .foregroundStyle(canSave ? Self.redditOrange : Self.redditOrange.opacity(0.4))
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
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedSubreddits.isEmpty
    }
    private func save() {
        guard canSave else { return }
        let selectedSubs = subreddits.filter { selectedSubreddits.contains($0.id) }
        onSave(CaptureFormResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes, links: links,
            project: selectedProject, subreddits: selectedSubs, mediaURLs: droppedFiles
        ))
    }
    private func populateFromMode() {
        switch mode {
        case .create:
            if let defaultId = UserDefaults.standard.string(forKey: SettingsKey.defaultProjectId),
               let uuid = UUID(uuidString: defaultId) {
                selectedProject = projects.first { $0.id == uuid }
            }
        case .edit(let capture):
            text = capture.text
            notes = capture.notes ?? ""
            selectedProject = capture.project
            selectedSubreddits = Set(capture.subreddits.map(\.id))
            links = capture.links
        }
    }
}
