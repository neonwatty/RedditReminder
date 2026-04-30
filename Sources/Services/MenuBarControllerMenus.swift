import AppKit

extension MenuBarController {
  // MARK: - Menu Shortcuts (⌘N, ⌘,)

  func installMenuShortcuts() {
    let mainMenu = NSMenu()

    let appMenu = NSMenu()
    let appMenuItem = NSMenuItem(title: "RedditReminder", action: nil, keyEquivalent: "")
    appMenuItem.submenu = appMenu
    let prefsItem = NSMenuItem(
      title: Self.settingsMenuItemTitle, action: #selector(handleOpenPreferences),
      keyEquivalent: ",")
    prefsItem.target = self
    appMenu.addItem(prefsItem)
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(
      withTitle: "Quit RedditReminder",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    mainMenu.addItem(appMenuItem)

    let fileMenu = NSMenu(title: "File")
    let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    fileMenuItem.submenu = fileMenu
    let newCaptureItem = NSMenuItem(
      title: "New Capture", action: #selector(handleNewCapture), keyEquivalent: "n")
    newCaptureItem.target = self
    fileMenu.addItem(newCaptureItem)
    mainMenu.addItem(fileMenuItem)

    #if DEBUG
      installQAMenu(on: mainMenu)
    #endif

    NSApp.mainMenu = mainMenu
  }

  @objc private func handleNewCapture() {
    onNewCapture?()
  }

  @objc private func handleOpenPreferences() {
    onOpenPreferences?()
  }
}

#if DEBUG
  extension MenuBarController {
    private func installQAMenu(on mainMenu: NSMenu) {
      let qaMenu = NSMenu(title: "QA")
      let qaMenuItem = NSMenuItem(title: "QA", action: nil, keyEquivalent: "")
      qaMenuItem.submenu = qaMenu

      addQAItem("Copy First Queued Capture", #selector(handleQACopyFirstQueuedCapture), to: qaMenu)
      addQAItem(
        "Copy First Queued Capture Title", #selector(handleQACopyFirstQueuedCaptureTitle), to: qaMenu)
      addQAItem(
        "Copy First Queued Capture Summary", #selector(handleQACopyFirstQueuedCaptureSummary),
        to: qaMenu)
      addQAItem("Copy First Queued Submit URL", #selector(handleQACopyFirstQueuedSubmitURL), to: qaMenu)
      addQAItem("Mark First Queued Capture Posted", #selector(handleQAMarkFirstQueuedCapturePosted), to: qaMenu)
      addQAItem(
        "Mark First Queued Capture Posted With URL",
        #selector(handleQAMarkFirstQueuedCapturePostedWithURL),
        to: qaMenu
      )
      addQAItem("Copy First Posted Capture Summary", #selector(handleQACopyFirstPostedCaptureSummary), to: qaMenu)
      addQAItem("Copy First Posted URL", #selector(handleQACopyFirstPostedURL), to: qaMenu)

      qaMenu.addItem(NSMenuItem.separator())
      addQAItem("Create Test Capture", #selector(handleQACreateTestCapture), to: qaMenu)
      addQAItem("Create Title Only Test Capture", #selector(handleQACreateTitleOnlyTestCapture), to: qaMenu)
      addQAItem(
        "Create Multi Subreddit Test Capture", #selector(handleQACreateMultiSubredditTestCapture),
        to: qaMenu)
      addQAItem("Delete Test Captures", #selector(handleQADeleteTestCaptures), to: qaMenu)

      mainMenu.addItem(qaMenuItem)
    }

    private func addQAItem(_ title: String, _ action: Selector, to menu: NSMenu) {
      let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
      item.target = self
      menu.addItem(item)
    }

    @objc private func handleQACopyFirstQueuedCapture() {
      onQACopyFirstQueuedCapture?()
    }

    @objc private func handleQACopyFirstQueuedSubmitURL() {
      onQACopyFirstQueuedSubmitURL?()
    }

    @objc private func handleQAMarkFirstQueuedCapturePosted() {
      onQAMarkFirstQueuedCapturePosted?()
    }

    @objc private func handleQAMarkFirstQueuedCapturePostedWithURL() {
      onQAMarkFirstQueuedCapturePostedWithURL?()
    }

    @objc private func handleQACreateTestCapture() {
      onQACreateTestCapture?()
    }

    @objc private func handleQACreateTitleOnlyTestCapture() {
      onQACreateTitleOnlyTestCapture?()
    }

    @objc private func handleQACreateMultiSubredditTestCapture() {
      onQACreateMultiSubredditTestCapture?()
    }

    @objc private func handleQADeleteTestCaptures() {
      onQADeleteTestCaptures?()
    }

    @objc private func handleQACopyFirstQueuedCaptureTitle() {
      onQACopyFirstQueuedCaptureTitle?()
    }

    @objc private func handleQACopyFirstQueuedCaptureSummary() {
      onQACopyFirstQueuedCaptureSummary?()
    }

    @objc private func handleQACopyFirstPostedCaptureSummary() {
      onQACopyFirstPostedCaptureSummary?()
    }

    @objc private func handleQACopyFirstPostedURL() {
      onQACopyFirstPostedURL?()
    }
  }
#endif
