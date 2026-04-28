import Foundation

enum CaptureHelpers {
    /// Normalizes a user-entered link, prepending https:// if needed.
    /// Returns nil for empty/whitespace input.
    static func normalizeLink(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
    }

    /// Validates that a capture form has the minimum required fields.
    static func canSave(text: String, selectedSubredditCount: Int) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedSubredditCount > 0
    }

    static func matchesSearch(_ capture: Capture, query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }

        let fields = [
            capture.text,
            capture.notes ?? "",
            capture.project?.name ?? "",
            capture.project?.projectDescription ?? ""
        ] + capture.links + capture.mediaRefs + capture.subreddits.map(\.name)

        return fields.contains { $0.lowercased().contains(normalized) }
    }

    /// Renders Reddit-flavored markdown to AttributedString.
    /// Strips ~~strikethrough~~ markers since AttributedString lacks support.
    /// Returns nil if parsing fails.
    static func renderMarkdown(_ input: String) -> AttributedString? {
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
