import AppKit
import Testing

@testable import RedditReminder

private final class MockPasteboard: PasteboardWriting {
  var cleared = false
  var storedString: String?
  var shouldSucceed = true

  func clearContents() -> Int {
    cleared = true
    return 1
  }

  func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
    storedString = string
    return shouldSucceed
  }
}

@Test func redditSubmitURLAcceptsPrefixedSubreddit() {
  #expect(
    RedditPostingActions.submitURL(forSubredditName: "r/SwiftUI")?
      .absoluteString == "https://www.reddit.com/r/SwiftUI/submit"
  )
}

@Test func redditSubmitURLAcceptsBareSubreddit() {
  #expect(
    RedditPostingActions.submitURL(forSubredditName: "SwiftUI")?
      .absoluteString == "https://www.reddit.com/r/SwiftUI/submit"
  )
}

@Test func redditSubmitURLRejectsInvalidSubreddit() {
  #expect(RedditPostingActions.submitURL(forSubredditName: "not a subreddit") == nil)
  #expect(RedditPostingActions.submitURL(forSubredditName: "  ") == nil)
}

@Test @MainActor func redditSubmitURLUsesFirstCaptureSubreddit() {
  let capture = Capture(
    text: "Launch post",
    subreddits: [
      Subreddit(name: "r/SwiftUI", sortOrder: 0), Subreddit(name: "r/macOS", sortOrder: 1),
    ]
  )

  #expect(
    RedditPostingActions.submitURL(for: capture)?
      .absoluteString == "https://www.reddit.com/r/SwiftUI/submit"
  )
}

@Test @MainActor func redditSubmitURLUsesSubredditSortOrder() {
  let capture = Capture(
    text: "Launch post",
    subreddits: [
      Subreddit(name: "r/macOS", sortOrder: 2), Subreddit(name: "r/SideProject", sortOrder: 0),
    ]
  )

  #expect(
    RedditPostingActions.submitURL(for: capture)?
      .absoluteString == "https://www.reddit.com/r/SideProject/submit"
  )
}

@Test @MainActor func clipboardTextIncludesCaptureTextOnly() {
  let capture = Capture(text: "  Ship notes  ")

  #expect(RedditPostingActions.clipboardText(for: capture) == "Ship notes")
}

@Test @MainActor func clipboardTextIncludesLinksAfterText() {
  let capture = Capture(
    text: "Launch post",
    links: [" https://example.com ", "", "https://github.com/example/app"]
  )

  #expect(
    RedditPostingActions.clipboardText(for: capture)
      == "Launch post\n\nhttps://example.com\nhttps://github.com/example/app"
  )
}

@Test @MainActor func clipboardTextCanIncludeNotesWhenRequested() {
  let capture = Capture(
    text: "Launch post",
    notes: "  Mention pricing  ",
    links: ["https://example.com"]
  )

  #expect(
    RedditPostingActions.clipboardText(for: capture, includeNotes: true)
      == "Launch post\n\nhttps://example.com\n\nNotes:\nMention pricing"
  )
}

@Test @MainActor func titleTextTrimsSavedTitle() {
  let capture = Capture(title: "  Launch notes  ", text: "Post body")

  #expect(RedditPostingActions.titleText(for: capture) == "Launch notes")
}

@Test @MainActor func linksTextTrimsAndSkipsEmptyLinks() {
  let capture = Capture(
    text: "Post body",
    links: [" https://example.com ", "", "  https://github.com/example/app  "]
  )

  #expect(
    RedditPostingActions.linksText(for: capture)
      == "https://example.com\nhttps://github.com/example/app"
  )
}

@Test @MainActor func handoffTextIncludesTitleBodyAndLinks() {
  let capture = Capture(
    title: "Launch notes",
    text: "Post body",
    links: ["https://example.com"]
  )

  #expect(
    RedditPostingActions.handoffText(for: capture)
      == "Launch notes\n\nPost body\n\nhttps://example.com"
  )
}

@Test @MainActor func handoffTextOmitsEmptyTitle() {
  let capture = Capture(title: "  ", text: "Post body")

  #expect(RedditPostingActions.handoffText(for: capture) == "Post body")
}

@Test func copyTextWritesToPasteboard() {
  let pasteboard = MockPasteboard()

  #expect(RedditPostingActions.copyText("Post body", to: pasteboard))
  #expect(pasteboard.cleared)
  #expect(pasteboard.storedString == "Post body")
}

@Test func copyTextReturnsPasteboardFailure() {
  let pasteboard = MockPasteboard()
  pasteboard.shouldSucceed = false

  #expect(RedditPostingActions.copyText("Post body", to: pasteboard) == false)
  #expect(pasteboard.cleared)
  #expect(pasteboard.storedString == "Post body")
}
