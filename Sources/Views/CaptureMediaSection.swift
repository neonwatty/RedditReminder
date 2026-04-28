import SwiftUI
import UniformTypeIdentifiers

struct CaptureMediaSection: View {
    @Binding var droppedFiles: [URL]
    var captureId: UUID?
    @Binding var existingRefs: [String]
    @Binding var removedRefs: [String]
    var mediaStore: MediaStore = MediaStore()

    @State private var isDragOver: Bool = false
    @State private var isShowingImporter: Bool = false
    @State private var previewImage: PreviewImage?

    var body: some View {
        VStack(spacing: 8) {
            if let captureId, !existingRefs.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(existingRefs, id: \.self) { ref in
                        mediaChip(
                            title: ref,
                            image: mediaStore.loadThumbnail(captureId: captureId, ref: ref),
                            onPreview: {
                                if let image = mediaStore.loadImage(captureId: captureId, ref: ref) {
                                    previewImage = PreviewImage(value: image)
                                }
                            },
                            onRemove: {
                                existingRefs.removeAll { $0 == ref }
                                removedRefs.append(ref)
                            }
                        )
                    }
                }
            }

            if !droppedFiles.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(droppedFiles.enumerated()), id: \.element) { index, url in
                        mediaChip(
                            title: url.lastPathComponent,
                            image: NSImage(contentsOf: url),
                            onPreview: {
                                if let image = NSImage(contentsOf: url) {
                                    previewImage = PreviewImage(value: image)
                                }
                            },
                            onRemove: { droppedFiles.remove(at: index) }
                        )
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
                .onTapGesture { isShowingImporter = true }
                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                    handleFileDrop(providers)
                }
                .fileImporter(
                    isPresented: $isShowingImporter,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        droppedFiles.append(contentsOf: urls)
                    case .failure(let error):
                        NSLog("RedditReminder: media import failed: \(error)")
                    }
                }
        }
        .sheet(item: $previewImage) { image in
            VStack(spacing: 0) {
                Image(nsImage: image.value)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 720, maxHeight: 520)
                    .padding(12)
            }
            .frame(minWidth: 420, minHeight: 300)
        }
    }

    init(
        droppedFiles: Binding<[URL]>,
        captureId: UUID? = nil,
        existingRefs: Binding<[String]> = .constant([]),
        removedRefs: Binding<[String]> = .constant([]),
        mediaStore: MediaStore = MediaStore()
    ) {
        self._droppedFiles = droppedFiles
        self.captureId = captureId
        self._existingRefs = existingRefs
        self._removedRefs = removedRefs
        self.mediaStore = mediaStore
    }

    private func mediaChip(
        title: String,
        image: NSImage?,
        onPreview: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 5) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 9))
            }
            Button(action: onPreview) {
                Text(title)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            Button(action: onRemove) {
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

    private struct PreviewImage: Identifiable {
        let id = UUID()
        let value: NSImage
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let error {
                    NSLog("RedditReminder: file drop failed: \(error)")
                    return
                }
                if let url { Task { @MainActor in droppedFiles.append(url) } }
            }
        }
        return true
    }
}
