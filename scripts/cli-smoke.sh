#!/usr/bin/env bash
set -euo pipefail

CLI="${1:-build/Build/Products/Debug/redditreminder}"
TMP_DIR="$(mktemp -d)"
STORE="$TMP_DIR/redditreminder-cli.store"
VERIFY_PORT="$((RANDOM + 20000))"
VERIFY_BASE_URL="http://127.0.0.1:$VERIFY_PORT"
VERIFY_SERVER_PID=""

cleanup() {
  if [[ -n "$VERIFY_SERVER_PID" ]]; then
    kill "$VERIFY_SERVER_PID" 2>/dev/null || true
    wait "$VERIFY_SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_json() {
  "$CLI" --json --store "$STORE" "$@"
}

run_json_with_verify_base() {
  REDDITREMINDER_VERIFY_BASE_URL="$VERIFY_BASE_URL" "$CLI" --json --store "$STORE" "$@"
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

mkdir -p "$TMP_DIR/mock/r/SideProject" "$TMP_DIR/mock/r/MissingSub"
printf '{"data":{"display_name_prefixed":"r/SideProject","title":"Side Project","subscribers":12345,"over18":false}}' \
  >"$TMP_DIR/mock/r/SideProject/about.json"
(
  cd "$TMP_DIR/mock"
  python3 -m http.server "$VERIFY_PORT" --bind 127.0.0.1 >/dev/null 2>&1
) &
VERIFY_SERVER_PID="$!"
for _ in {1..20}; do
  if curl -fsS "$VERIFY_BASE_URL/r/SideProject/about.json" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

projects_empty="$(run_json projects list)"
assert_contains "empty projects list" "$projects_empty" '"ok":true'

project_created="$(run_json projects create "Launch Ideas")"
assert_contains "project create ok" "$project_created" '"ok":true'
assert_contains "project create name" "$project_created" '"name":"Launch Ideas"'

scratch_project_created="$(run_json projects create "Scratch Project")"
assert_contains "scratch project create" "$scratch_project_created" '"name":"Scratch Project"'

scratch_project_updated="$(run_json projects update "Scratch Project" --name "Scratch Plan" --description "Temporary config" --color "#FF4500" --archive)"
assert_contains "project update ok" "$scratch_project_updated" '"ok":true'
assert_contains "project update name" "$scratch_project_updated" '"name":"Scratch Plan"'
assert_contains "project update description" "$scratch_project_updated" '"description":"Temporary config"'
assert_contains "project update color" "$scratch_project_updated" '"color":"#FF4500"'
assert_contains "project update archive" "$scratch_project_updated" '"archived":true'

scratch_project_unarchived="$(run_json projects update "Scratch Plan" --unarchive --clear-description --clear-color)"
assert_contains "project unarchive" "$scratch_project_unarchived" '"archived":false'

scratch_project_deleted="$(run_json projects delete "Scratch Plan")"
assert_contains "project delete ok" "$scratch_project_deleted" '"ok":true'

subreddit_verified="$(run_json_with_verify_base subreddits verify SideProject)"
assert_contains "subreddit verify ok" "$subreddit_verified" '"ok":true'
assert_contains "subreddit verify exists" "$subreddit_verified" '"exists":true'
assert_contains "subreddit verify title" "$subreddit_verified" '"title":"Side Project"'

subreddit_created="$(run_json_with_verify_base subreddits add --verify SideProject)"
assert_contains "subreddit add ok" "$subreddit_created" '"ok":true'
assert_contains "subreddit normalized" "$subreddit_created" '"name":"r/SideProject"'

if run_json_with_verify_base subreddits add --verify MissingSub >/tmp/redditreminder-cli-missing-sub.out 2>/tmp/redditreminder-cli-missing-sub.err; then
  echo "FAIL: missing subreddit add unexpectedly succeeded" >&2
  exit 1
fi
assert_contains "missing subreddit rejected" "$(cat /tmp/redditreminder-cli-missing-sub.err)" "could not be verified"
rm -f /tmp/redditreminder-cli-missing-sub.out /tmp/redditreminder-cli-missing-sub.err

scratch_subreddit_created="$(run_json subreddits add TempSub)"
assert_contains "scratch subreddit create" "$scratch_subreddit_created" '"name":"r/TempSub"'

scratch_subreddit_updated="$(run_json subreddits update TempSub --name TempRenamed --checklist "Read rules before posting")"
assert_contains "subreddit update ok" "$scratch_subreddit_updated" '"ok":true'
assert_contains "subreddit update name" "$scratch_subreddit_updated" '"name":"r/TempRenamed"'
assert_contains "subreddit update checklist" "$scratch_subreddit_updated" '"postingChecklist":"Read rules before posting"'

scratch_subreddit_cleared="$(run_json subreddits update TempRenamed --clear-checklist)"
assert_contains "subreddit clear checklist ok" "$scratch_subreddit_cleared" '"ok":true'

scratch_subreddit_deleted="$(run_json subreddits delete TempRenamed)"
assert_contains "subreddit delete ok" "$scratch_subreddit_deleted" '"ok":true'

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

global_search="$(run_json search all --query "Launch" --limit 10)"
assert_contains "global search ok" "$global_search" '"ok":true'
assert_contains "global search project" "$global_search" '"kind":"project"'

context_snapshot="$(run_json context show --limit 5)"
assert_contains "context ok" "$context_snapshot" '"ok":true'
assert_contains "context counts" "$context_snapshot" '"counts":'
assert_contains "context subreddits" "$context_snapshot" '"subreddits":['
assert_contains "context peak presets" "$context_snapshot" '"peakPresets":['

commands_list="$(run_json commands list)"
assert_contains "commands list ok" "$commands_list" '"ok":true'
assert_contains "commands list captures create" "$commands_list" '"id":"captures.create"'
assert_contains "commands list output" "$commands_list" '"output":'

commands_show="$(run_json commands show captures.create)"
assert_contains "commands show ok" "$commands_show" '"ok":true'
assert_contains "commands show id" "$commands_show" '"id":"captures.create"'
assert_contains "commands show media flag" "$commands_show" '"name":"--media"'
assert_contains "commands show output kind" "$commands_show" '"data":"captureCreated"'

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
