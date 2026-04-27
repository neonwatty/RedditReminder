import SwiftUI

struct CaptureMediaSection: View {
    @Binding var droppedFiles: [URL]
    @Binding var isDragOver: Bool

    var body: some View {
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

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in droppedFiles.append(url) } }
            }
        }
        return true
    }
}
