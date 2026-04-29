import SwiftUI

struct CaptureMediaChip: View {
    let title: String
    let image: NSImage?
    let previewIdentifier: String
    let removeIdentifier: String
    let onPreview: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            mediaIcon
            Button(action: onPreview) {
                Text(title)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(previewIdentifier)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(removeIdentifier)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var mediaIcon: some View {
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
    }
}

struct RemovedCaptureMediaChip: View {
    let title: String
    let image: NSImage?
    let restoreIdentifier: String
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            mediaIcon
            Text(title)
                .font(.system(size: 10))
                .lineLimit(1)
                .strikethrough()
                .foregroundStyle(.secondary)
            Button(action: onRestore) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(restoreIdentifier)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var mediaIcon: some View {
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
    }
}
