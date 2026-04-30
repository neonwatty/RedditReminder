# Posting Actions QA

Manual checklist for the popover posting actions.

For the full end-to-end checklist, see [Manual QA Workflows](manual-qa-workflows.md).

1. Run `make install-debug`.
2. Launch `~/Applications/RedditReminder.app --args --seed-qa`, or run `make qa` to seed fixtures.
3. Open the menu bar popover.
4. Click the copy icon on a queued capture.
5. Confirm the clipboard contains the capture text and links.
6. Click the Reddit submit icon on a queued capture.
7. Confirm the browser opens `https://www.reddit.com/r/<subreddit>/submit`.
8. Click the mark-posted icon.
9. Confirm the capture leaves Queue and appears under Posted.
10. Hover the urgency dot on an urgent capture and confirm the tooltip explains the posting window urgency.
