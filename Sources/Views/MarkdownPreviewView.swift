import SwiftUI

struct MarkdownPreviewView: View {
    let text: String

    var body: some View {
        ScrollView {
            if let attributed = renderMarkdown(text) {
                Text(attributed)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            } else {
                Text(text)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    private func renderMarkdown(_ input: String) -> AttributedString? {
        // Convert Reddit ~~strikethrough~~ to standard markdown
        // Just strip ~~ for now since AttributedString doesn't support strikethrough
        let processed = input.replacingOccurrences(
            of: "~~(.+?)~~",
            with: "$1",
            options: .regularExpression
        )

        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(markdown: processed, options: options)
        } catch {
            return nil
        }
    }
}
