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

peak_get="$(run_json peaks get SideProject)"
assert_contains "peak get" "$peak_get" '"source":"override"'

peak_reset="$(run_json peaks reset SideProject)"
assert_contains "peak reset" "$peak_reset" '"ok":true'

captures="$(run_json captures list)"
assert_contains "captures list" "$captures" '"ok":true'

echo "CLI smoke passed"
