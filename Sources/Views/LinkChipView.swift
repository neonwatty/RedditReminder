import SwiftUI

struct LinkChipView: View {
    let url: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: 10))
            Text(displayURL)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(StickerColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(StickerColors.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(StickerColors.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(StickerColors.blue.opacity(0.4), lineWidth: 2)
        )
    }

    private var displayURL: String {
        var display = url
        if display.hasPrefix("https://") { display = String(display.dropFirst(8)) }
        if display.hasPrefix("http://") { display = String(display.dropFirst(7)) }
        if display.hasPrefix("www.") { display = String(display.dropFirst(4)) }
        return display
    }
}
