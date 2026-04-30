# Manual QA Workflows

Use this checklist after UX changes to verify the app still supports the full posting workflow. Record the date, build, and tester at the top of a copied run log if you want an audit trail.

## Setup

- [ ] Run `make test`.
- [ ] Run `./scripts/format-check.sh`.
- [ ] Install the debug build with `make install-debug`.
- [ ] Launch `~/Applications/RedditReminder.app`.
- [ ] If using seeded data, run `make qa` or launch with `--args --seed-qa`.

## 1. First-Run Setup

- [ ] Open Settings with `Cmd+,`.
- [ ] Go to Channels.
- [ ] Add a subreddit.
- [ ] Add or edit its posting checklist.
- [ ] Collapse and expand the row.
- [ ] Confirm the collapsed row shows a checklist indicator.
- [ ] Quit and relaunch.
- [ ] Confirm the subreddit and checklist persisted.

## 2. Create Capture

- [ ] Press `Cmd+N`.
- [ ] Enter a title.
- [ ] Enter body text.
- [ ] Add links or media if available.
- [ ] Select one or more subreddits.
- [ ] Save.
- [ ] Confirm the capture appears in the popover queue.
- [ ] Confirm the title appears above the body.
- [ ] Confirm selected subreddit names appear.
- [ ] Edit the capture if editing is available.
- [ ] Confirm changes persist.

## 3. Post Handoff

- [ ] From a capture card, open the post handoff action.
- [ ] Confirm the handoff window opens.
- [ ] Confirm title, body, links, and checklist content are correct.
- [ ] Copy the title.
- [ ] Paste into a text editor and verify content.
- [ ] Copy the body.
- [ ] Paste into a text editor and verify content.
- [ ] Copy links.
- [ ] Paste into a text editor and verify content.
- [ ] Copy all.
- [ ] Paste into a text editor and verify formatting.
- [ ] Use the Reddit submit/open action.
- [ ] Confirm the body is copied and Reddit opens.

## 4. Mark Posted

- [ ] Mark a queued capture as posted.
- [ ] When prompted, paste a Reddit post URL.
- [ ] Confirm the capture leaves the queue.
- [ ] Open the posted/history view.
- [ ] Confirm title, body, subreddit, and date appear.
- [ ] Open the saved Reddit URL.
- [ ] Repeat with another capture and leave the URL blank.
- [ ] Confirm history records the post without showing a broken link.

## 5. Delete Safety

- [ ] Create a disposable capture.
- [ ] Click delete.
- [ ] Cancel the confirmation.
- [ ] Confirm the capture remains.
- [ ] Delete again and confirm.
- [ ] Confirm the capture is removed.

## 6. Planner

- [ ] Open Settings > Planner.
- [ ] Confirm upcoming windows are grouped by Today, Tomorrow, or date.
- [ ] Confirm rows show subreddit/event title.
- [ ] Confirm rows show a short time.
- [ ] Confirm rows show queue readiness.
- [ ] Confirm rows show Auto or Manual.
- [ ] Add a capture for one listed subreddit.
- [ ] Return to Planner.
- [ ] Confirm readiness count updates.
- [ ] Post or delete the capture.
- [ ] Confirm readiness updates again.

## 7. Backup And Restore

- [ ] Create at least one subreddit with a checklist.
- [ ] Create one queued capture with a title.
- [ ] Mark one capture posted with a URL.
- [ ] Export a backup.
- [ ] Import the backup into a clean or disposable data store if available.
- [ ] Confirm capture title survives.
- [ ] Confirm posted URL survives.
- [ ] Confirm checklist survives.
- [ ] Confirm capture status survives.

## 8. Keyboard Shortcuts

- [ ] Close the popover.
- [ ] Press `Cmd+N`.
- [ ] Confirm the capture window opens.
- [ ] Press `Cmd+,`.
- [ ] Confirm settings open.
- [ ] Trigger `Cmd+N` while the popover is already open.
- [ ] Confirm behavior is consistent and duplicate windows do not appear.
- [ ] Trigger `Cmd+,` while settings are already open.
- [ ] Confirm behavior is consistent and duplicate windows do not appear.

## 9. Relaunch Persistence

- [ ] Create a subreddit checklist.
- [ ] Create a queued capture.
- [ ] Mark another capture posted with a URL.
- [ ] Quit the app.
- [ ] Relaunch the app.
- [ ] Confirm the queue still looks correct.
- [ ] Confirm posted history still looks correct.
- [ ] Confirm checklist content still looks correct.
- [ ] Confirm planner data still looks correct.

## 10. Edge Cases

- [ ] Create a capture with title only.
- [ ] Create a capture with body only.
- [ ] Create a capture with a long title.
- [ ] Create a capture with a long body.
- [ ] Create a capture assigned to multiple subreddits.
- [ ] Add a checklist with blank lines.
- [ ] Confirm blank checklist lines do not render as weird empty bullets.
- [ ] Confirm long text does not clip, overlap, or push controls offscreen.

## Notes

- `make qa` can help seed and exercise app flows, but some macOS UI automation may require local Accessibility or Screen Recording permissions.
- For visual QA, prefer testing at least one small window size and one normal desktop size.
- If a failure is found, add the exact workflow step, expected result, actual result, and screenshot path to the issue or PR notes.
