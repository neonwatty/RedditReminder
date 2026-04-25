import SwiftUI

struct CaptureFormView: View {
    let projects: [Project]
    let subreddits: [Subreddit]
    let onSave: (String, String?, Project, [Subreddit], [URL]) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @State private var notes = ""
    @State private var selectedProject: Project?
    @State private var selectedSubreddits: Set<UUID> = []
    @State private var droppedFiles: [URL] = []
    @State private var isDragOver = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("New Capture")

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PROJECT").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(StickerColors.textSecondary)
                            Picker("", selection: $selectedProject) {
                                Text("Select...").tag(nil as Project?)
                                ForEach(projects.filter { !$0.archived }, id: \.id) { project in
                                    Text(project.name).tag(project as Project?)
                                }
                            }
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("SUBREDDITS").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(StickerColors.textSecondary)
                            subredditMultiSelect
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("WHAT HAPPENED?").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(StickerColors.textSecondary)
                        TextEditor(text: $text)
                            .font(.system(size: 12))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .stickerInput()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("NOTES TO SELF").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(StickerColors.textSecondary)
                        TextField("e.g., mention the screenshot, link the demo...", text: $notes)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .stickerInput()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("MEDIA").font(.system(size: 9, weight: .medium)).tracking(0.5).foregroundStyle(StickerColors.textSecondary)
                        dropZone
                        attachedFiles
                    }
                }
                .padding(12)
            }

            Rectangle()
                .fill(StickerColors.border)
                .frame(height: 2)
            captureFormFooter
        }
    }

    private var captureFormFooter: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(StickerColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(StickerColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(StickerColors.border, lineWidth: 2)
                )

            Button(action: save) {
                Text("Add to Queue \u{2318}\u{21A9}")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(canSave ? Color(nsColor: AppColors.reddit) : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(StickerColors.border, lineWidth: 2)
                    )
                    .shadow(color: StickerColors.border.opacity(0.5), radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(12)
    }

    private var canSave: Bool {
        !text.isEmpty && selectedProject != nil && !selectedSubreddits.isEmpty
    }

    private func save() {
        guard let project = selectedProject else { return }
        let subs = subreddits.filter { selectedSubreddits.contains($0.id) }
        onSave(text, notes.isEmpty ? nil : notes, project, subs, droppedFiles)
    }

    private var subredditMultiSelect: some View {
        HStack(spacing: 4) {
            ForEach(subreddits.filter { selectedSubreddits.contains($0.id) }, id: \.id) { sub in
                SubredditChip(name: sub.name, onRemove: { selectedSubreddits.remove(sub.id) })
            }

            Menu("+ add") {
                ForEach(subreddits.filter { !selectedSubreddits.contains($0.id) }, id: \.id) { sub in
                    Button(sub.name) { selectedSubreddits.insert(sub.id) }
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(StickerColors.textSecondary)
        }
        .padding(6)
        .stickerInput()
    }

    private var dropZone: some View {
        DropZoneView(isDragOver: isDragOver)
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url {
                            DispatchQueue.main.async {
                                droppedFiles.append(url)
                            }
                        }
                    }
                }
                return true
            }
    }

    @ViewBuilder
    private var attachedFiles: some View {
        if !droppedFiles.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(droppedFiles.enumerated()), id: \.offset) { idx, url in
                    AttachedFileChip(filename: url.lastPathComponent, onRemove: { droppedFiles.remove(at: idx) })
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(StickerColors.textSecondary)
    }
}

// MARK: - Sub-views extracted to avoid type-checking complexity

private struct SubredditChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Text(name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: AppColors.reddit))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(nsColor: AppColors.reddit).opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(nsColor: AppColors.reddit), lineWidth: 2))
    }
}

private struct DropZoneView: View {
    let isDragOver: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDragOver ? Color(nsColor: AppColors.reddit) : StickerColors.border,
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .background(
                    isDragOver
                        ? Color(nsColor: AppColors.reddit).opacity(0.05)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 4) {
                Image(systemName: "paperclip")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isDragOver ? Color(nsColor: AppColors.reddit) : StickerColors.textSecondary)
                Text("Drop images or videos here")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isDragOver ? Color(nsColor: AppColors.reddit) : StickerColors.textSecondary)
                Text("PNG, JPG, GIF, MP4")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .padding(.vertical, 20)
        }
    }
}

private struct AttachedFileChip: View {
    let filename: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc")
                .font(.system(size: 10))
            Text(filename)
                .font(.system(size: 10))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(StickerColors.textPrimary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(StickerColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(StickerColors.border, lineWidth: 1)
        )
    }
}
