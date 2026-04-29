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
                        CaptureMediaChip(
                            title: ref,
                            image: mediaStore.loadThumbnail(captureId: captureId, ref: ref),
                            previewIdentifier: CaptureMediaAccessibility.previewExisting(ref: ref),
                            removeIdentifier: CaptureMediaAccessibility.removeExisting(ref: ref),
                            onPreview: {
                                if let image = mediaStore.loadImage(captureId: captureId, ref: ref) {
                                    previewImage = PreviewImage(value: image)
                                }
                            },
                            onRemove: {
                                CaptureMediaEditing.removeExisting(
                                    ref: ref,
                                    existingRefs: &existingRefs,
                                    removedRefs: &removedRefs
                                )
                            }
                        )
                    }
                }
            }

            if let captureId, !removedRefs.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(removedRefs, id: \.self) { ref in
                        RemovedCaptureMediaChip(
                            title: ref,
                            image: mediaStore.loadThumbnail(captureId: captureId, ref: ref),
                            restoreIdentifier: CaptureMediaAccessibility.restoreExisting(ref: ref),
                            onRestore: {
                                CaptureMediaEditing.restoreExisting(
                                    ref: ref,
                                    existingRefs: &existingRefs,
                                    removedRefs: &removedRefs
                                )
                            }
                        )
                    }
                }
            }

            if !droppedFiles.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(droppedFiles.enumerated()), id: \.offset) { index, url in
                        CaptureMediaChip(
                            title: url.lastPathComponent,
                            image: NSImage(contentsOf: url),
                            previewIdentifier: CaptureMediaAccessibility.previewNew(fileName: url.lastPathComponent),
                            removeIdentifier: CaptureMediaAccessibility.removeNew(index: index),
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
                .accessibilityIdentifier(CaptureMediaAccessibility.dropZone)
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
                        appendImageFiles(urls)
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

    private struct PreviewImage: Identifiable {
        let id = UUID()
        let value: NSImage
    }

    private func appendImageFiles(_ urls: [URL]) {
        let imageURLs = CaptureMediaSelection.imageURLs(from: urls)
        droppedFiles.append(contentsOf: imageURLs)
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let error {
                    NSLog("RedditReminder: file drop failed: \(error)")
                    return
                }
                if let url { Task { @MainActor in appendImageFiles([url]) } }
            }
        }
        return true
    }
}
