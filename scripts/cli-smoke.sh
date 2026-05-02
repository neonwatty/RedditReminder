#!/usr/bin/env bash
set -euo pipefail

CLI="${1:-build/Build/Products/Debug/redditreminder}"
TMP_DIR="$(mktemp -d)"
STORE="$TMP_DIR/redditreminder-cli.store"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_json() {
  "$CLI" --json --store "$STORE" "$@"
}

assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $label" >&2
    echo "Expected output to contain: $needle" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

projects_empty="$(run_json projects list)"
assert_contains "empty projects list" "$projects_empty" '"ok":true'

project_created="$(run_json projects create "Launch Ideas")"
assert_contains "project create ok" "$project_created" '"ok":true'
assert_contains "project create name" "$project_created" '"name":"Launch Ideas"'

subreddit_created="$(run_json subreddits add SideProject)"
assert_contains "subreddit add ok" "$subreddit_created" '"ok":true'
assert_contains "subreddit normalized" "$subreddit_created" '"name":"r/SideProject"'

if run_json subreddits add sideproject >/tmp/redditreminder-cli-duplicate.out 2>/tmp/redditreminder-cli-duplicate.err; then
  echo "FAIL: duplicate subreddit add unexpectedly succeeded" >&2
  exit 1
fi
assert_contains "duplicate subreddit rejected" "$(cat /tmp/redditreminder-cli-duplicate.err)" "already in your list"
rm -f /tmp/redditreminder-cli-duplicate.out /tmp/redditreminder-cli-duplicate.err

subreddit_search="$(run_json subreddits search --query side)"
assert_contains "subreddit search" "$subreddit_search" '"name":"r/SideProject"'

presets="$(run_json peaks presets)"
assert_contains "peak presets" "$presets" '"label":"Weekday AM"'

peak_set="$(run_json peaks set SideProject --days mon,wed --hours 9,10)"
assert_contains "peak set ok" "$peak_set" '"ok":true'
assert_contains "peak set source" "$peak_set" '"source":"override"'

generated_events="$(run_json events list --generated)"
assert_contains "generated events list" "$generated_events" '"isGeneratedFromHeuristics":true'
generated_event_id="$(printf '%s\n' "$generated_events" | perl -0ne 'print $1 if /"id":"([^"]+)"/')"
if [[ -z "$generated_event_id" || "$generated_event_id" == "$generated_events" ]]; then
  echo "FAIL: could not parse generated event id" >&2
  echo "$generated_events" >&2
  exit 1
fi
if run_json events update "$generated_event_id" --name "Should fail" >/tmp/redditreminder-cli-generated-update.out 2>/tmp/redditreminder-cli-generated-update.err; then
  echo "FAIL: generated event update unexpectedly succeeded" >&2
  exit 1
fi
assert_contains "generated update rejected" "$(cat /tmp/redditreminder-cli-generated-update.err)" "Generated peak events cannot be updated or deleted directly"
if run_json events delete "$generated_event_id" >/tmp/redditreminder-cli-generated-delete.out 2>/tmp/redditreminder-cli-generated-delete.err; then
  echo "FAIL: generated event delete unexpectedly succeeded" >&2
  exit 1
fi
assert_contains "generated delete rejected" "$(cat /tmp/redditreminder-cli-generated-delete.err)" "Generated peak events cannot be updated or deleted directly"
rm -f /tmp/redditreminder-cli-generated-update.out /tmp/redditreminder-cli-generated-update.err
rm -f /tmp/redditreminder-cli-generated-delete.out /tmp/redditreminder-cli-generated-delete.err

peak_get="$(run_json peaks get SideProject)"
assert_contains "peak get" "$peak_get" '"source":"override"'

peak_reset="$(run_json peaks reset SideProject)"
assert_contains "peak reset" "$peak_reset" '"ok":true'

event_created="$(run_json events create --subreddit SideProject --name "Manual launch window" --date "2026-05-02T20:00:00Z" --lead-minutes 30)"
assert_contains "event create ok" "$event_created" '"ok":true'
assert_contains "event create name" "$event_created" '"name":"Manual launch window"'
assert_contains "event create date" "$event_created" '"oneOffDate":"2026-05-02T20:00:00Z"'
assert_contains "event create lead" "$event_created" '"reminderLeadMinutes":30'
event_id="$(printf '%s\n' "$event_created" | perl -0ne 'print $1 if /"id":"([^"]+)"/')"
if [[ -z "$event_id" || "$event_id" == "$event_created" ]]; then
  echo "FAIL: could not parse event id" >&2
  echo "$event_created" >&2
  exit 1
fi

event_search="$(run_json events search --query launch --manual --active)"
assert_contains "event search" "$event_search" '"name":"Manual launch window"'

event_updated="$(run_json events update "$event_id" --name "Updated launch window" --date "2026-05-02T21:00:00Z" --lead-minutes 45)"
assert_contains "event update ok" "$event_updated" '"ok":true'
assert_contains "event update name" "$event_updated" '"name":"Updated launch window"'
assert_contains "event update date" "$event_updated" '"oneOffDate":"2026-05-02T21:00:00Z"'
assert_contains "event update lead" "$event_updated" '"reminderLeadMinutes":45'

event_deactivated="$(run_json events update "$event_id" --deactivate)"
assert_contains "event deactivate ok" "$event_deactivated" '"ok":true'
assert_contains "event deactivate active false" "$event_deactivated" '"isActive":false'

event_activated="$(run_json events update "$event_id" --activate)"
assert_contains "event activate ok" "$event_activated" '"ok":true'
assert_contains "event activate active true" "$event_activated" '"isActive":true'

event_deleted="$(run_json events delete "$event_id")"
assert_contains "event delete ok" "$event_deleted" '"ok":true'
assert_contains "event delete id" "$event_deleted" "\"id\":\"$event_id\""

IMAGE="$TMP_DIR/pixel.png"
sips -s format png /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns --out "$IMAGE" >/dev/null

capture_created="$(
  run_json captures create \
    --title "Launch post" \
    --text "Post body" \
    --notes "Private checklist" \
    --link "https://example.com" \
    --project "Launch Ideas" \
    --subreddit SideProject \
    --media "$IMAGE" \
    --due "2026-05-02T18:00:00Z"
)"
assert_contains "capture create ok" "$capture_created" '"ok":true'
assert_contains "capture create title" "$capture_created" '"title":"Launch post"'
assert_contains "capture create media" "$capture_created" '"mediaRefs":["pixel.png"]'
assert_contains "capture create due event" "$capture_created" '"oneOffDate":"2026-05-02T18:00:00Z"'
capture_id="$(printf '%s\n' "$capture_created" | perl -0ne 'print $1 if /"capture":\{"createdAt":"[^"]+","id":"([^"]+)"/')"
if [[ -z "$capture_id" || "$capture_id" == "$capture_created" ]]; then
  echo "FAIL: could not parse capture id" >&2
  echo "$capture_created" >&2
  exit 1
fi

capture_updated="$(run_json captures update "$capture_id" --title "Updated launch post" --clear-notes --links "https://example.com/updated")"
assert_contains "capture update ok" "$capture_updated" '"ok":true'
assert_contains "capture update title" "$capture_updated" '"title":"Updated launch post"'
assert_contains "capture update link" "$capture_updated" '"https://example.com/updated"'

capture_posted="$(run_json captures mark-posted "$capture_id" --url "https://reddit.com/r/SideProject/comments/abc")"
assert_contains "capture mark posted ok" "$capture_posted" '"ok":true'
assert_contains "capture mark posted status" "$capture_posted" '"status":"posted"'
assert_contains "capture mark posted url" "$capture_posted" '"postedURL":"https://reddit.com/r/SideProject/comments/abc"'

capture_queued="$(run_json captures mark-queued "$capture_id")"
assert_contains "capture mark queued ok" "$capture_queued" '"ok":true'
assert_contains "capture mark queued status" "$capture_queued" '"status":"queued"'

captures="$(run_json captures list)"
assert_contains "captures list" "$captures" '"ok":true'
assert_contains "captures list created" "$captures" '"title":"Updated launch post"'

capture_deleted="$(run_json captures delete "$capture_id")"
assert_contains "capture delete ok" "$capture_deleted" '"ok":true'
assert_contains "capture delete id" "$capture_deleted" "\"id\":\"$capture_id\""

deleted_search="$(run_json captures search --query "Updated launch post")"
assert_contains "capture deleted search" "$deleted_search" '"data":[]'

echo "CLI smoke passed"
