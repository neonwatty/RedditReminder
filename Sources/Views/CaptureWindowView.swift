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
                        Menu {
                            ForEach(subreddits, id: \.id) { sub in
                                Button(action: {
                                    if selectedSubreddits.contains(sub.id) {
                                        selectedSubreddits.remove(sub.id)
                                    } else {
                                        selectedSubreddits.insert(sub.id)
                                    }
                                }) {
                                    HStack {
                                        Text(sub.name)
                                        if selectedSubreddits.contains(sub.id) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if selectedSubreddits.isEmpty {
                                    Text("Select subreddit...")
                                        .foregroundStyle(.secondary)
                                } else {
                                    let names = subreddits
                                        .filter { selectedSubreddits.contains($0.id) }
                                        .map(\.name)
                                        .joined(separator: ", ")
                                    Text(names)
                                        .foregroundStyle(Self.redditOrange)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 12))
                            .padding(8)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                        }
                        .menuStyle(.borderlessButton)
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
                        FlowLayout(spacing: 6) {
                            ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                                LinkChipView(url: link, onRemove: {
                                    links.remove(at: index)
                                })
                            }

                            HStack(spacing: 4) {
                                TextField("Add link...", text: $newLinkText)
                                    .font(.system(size: 10))
                                    .textFieldStyle(.plain)
                                    .frame(width: 120)
                                    .onSubmit { addLink() }

                                if !newLinkText.isEmpty {
                                    Button(action: addLink) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Self.redditOrange)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            )
                        }
                    }

                    fieldSection("MEDIA") {
                        VStack(spacing: 8) {
                            if !droppedFiles.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(Array(droppedFiles.enumerated()), id: \.offset) { index, url in
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc")
                                                .font(.system(size: 9))
                                            Text(url.lastPathComponent)
                                                .font(.system(size: 10))
                                                .lineLimit(1)
                                            Button(action: { droppedFiles.remove(at: index) }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 7, weight: .bold))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary.opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }

                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .frame(height: 48)
                                .overlay {
                                    Text("Drop images here or ").font(.system(size: 11)).foregroundStyle(.secondary)
                                    + Text("browse").font(.system(size: 11)).foregroundStyle(.blue)
                                }
                                .background(isDragOver ? Color.blue.opacity(0.05) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                                    handleFileDrop(providers)
                                }
                        }
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
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in droppedFiles.append(url) } }
            }
        }
        return true
    }
    private func addLink() {
        let trimmed = newLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        links.append(trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)")
        newLinkText = ""
    }
    private func populateFromMode() {
        switch mode {
        case .create:
            let defaultId = UserDefaults.standard.string(forKey: "defaultProjectId") ?? ""
            if let uuid = UUID(uuidString: defaultId) {
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
