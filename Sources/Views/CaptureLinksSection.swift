import SwiftUI

struct CaptureLinksSection: View {
    @Binding var links: [String]
    @Binding var newLinkText: String

    private static let redditOrange = AppColors.redditOrange

    var body: some View {
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

    private func addLink() {
        let trimmed = newLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        links.append(trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)")
        newLinkText = ""
    }
}
