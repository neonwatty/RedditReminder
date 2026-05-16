import Foundation

enum CaptureHelpers {
    static let invalidLinkMessage = "Enter a valid http or https link."
    static let linkValidationAccessibilityIdentifier = "captureWindow.links.validation"

    /// Normalizes a user-entered link, prepending https:// if needed.
    /// Returns nil for empty/whitespace input.
    static func normalizeLink(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil,
              url.user == nil,
              url.password == nil else { return nil }

        return candidate
    }

    static func linkValidationMessage(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return normalizeLink(trimmed) == nil ? invalidLinkMessage : nil
    }

    /// Validates that a capture form has the minimum required fields.
    static func canSave(title: String, text: String, selectedSubredditCount: Int) -> Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasTitle || hasText) && selectedSubredditCount > 0
    }

    static func saveRequirementsMessage(
        title: String,
        text: String,
        selectedSubredditCount: Int
    ) -> String? {
        guard !canSave(title: title, text: text, selectedSubredditCount: selectedSubredditCount)
        else { return nil }

        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var requirements: [String] = []
        if !hasTitle && !hasText {
            requirements.append("add a title or capture text")
        }
        if selectedSubredditCount == 0 {
            requirements.append("select at least one subreddit")
        }
        return "To save, \(requirements.joined(separator: " and "))."
    }

    static func subredditSummary(for subreddits: [Subreddit]) -> String? {
        let names = subreddits
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.sortOrder < $1.sortOrder
            }
            .map(\.name)
        guard let first = names.first else { return nil }
        return names.count == 1 ? first : "\(first) +\(names.count - 1)"
    }

    static func matchesSearch(_ capture: Capture, query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }

        var fields: [String] = [
            capture.title ?? "",
            capture.text,
            capture.notes ?? "",
            capture.project?.name ?? "",
            capture.project?.projectDescription ?? "",
        ]
        fields.append(contentsOf: capture.links)
        fields.append(contentsOf: capture.mediaRefs)
        fields.append(contentsOf: capture.subreddits.map(\.name))

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
