import AppKit
import Foundation

protocol PasteboardWriting {
  @discardableResult
  func clearContents() -> Int
  @discardableResult
  func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardWriting {}

enum RedditPostingActions {
  static func subredditSlug(from name: String) -> String? {
    guard let normalized = SubredditName.normalizedName(name) else { return nil }
    return String(normalized.dropFirst(2))
  }

  static func submitURL(forSubredditName name: String) -> URL? {
    guard let slug = subredditSlug(from: name) else { return nil }
    return URL(string: "https://www.reddit.com/r/\(slug)/submit")
  }

  @MainActor
  static func submitURL(for capture: Capture) -> URL? {
    guard
      let subreddit = capture.subreddits.min(by: {
        if $0.sortOrder == $1.sortOrder {
          return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return $0.sortOrder < $1.sortOrder
      })
    else { return nil }
    return submitURL(forSubredditName: subreddit.name)
  }

  @MainActor
  static func titleText(for capture: Capture) -> String {
    capture.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  @MainActor
  static func linksText(for capture: Capture) -> String {
    capture.links
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  @MainActor
  static func clipboardText(for capture: Capture, includeNotes: Bool = false) -> String {
    var sections = [capture.text.trimmingCharacters(in: .whitespacesAndNewlines)]

    let links = linksText(for: capture)
    if !links.isEmpty {
      sections.append(links)
    }

    if includeNotes,
      let notes = capture.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
      !notes.isEmpty
    {
      sections.append("Notes:\n\(notes)")
    }

    return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  @MainActor
  static func handoffText(for capture: Capture, includeNotes: Bool = false) -> String {
    var sections: [String] = []
    let title = titleText(for: capture)
    if !title.isEmpty {
      sections.append(title)
    }
    let body = clipboardText(for: capture, includeNotes: includeNotes)
    if !body.isEmpty {
      sections.append(body)
    }
    return sections.joined(separator: "\n\n")
  }

  static func copyText(_ text: String, to pasteboard: any PasteboardWriting = NSPasteboard.general)
    -> Bool
  {
    pasteboard.clearContents()
    return pasteboard.setString(text, forType: .string)
  }
}
