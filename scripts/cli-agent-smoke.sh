#!/usr/bin/env bash
set -euo pipefail

CLI="${1:-build/Build/Products/Debug/redditreminder}"
TMP_DIR="$(mktemp -d)"
STORE="$TMP_DIR/redditreminder-agent.store"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_json() {
  "$CLI" --json --store "$STORE" "$@"
}

run_json_dry() {
  "$CLI" --json --dry-run --store "$STORE" "$@"
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

bootstrap="$(run_json agent bootstrap)"
assert_contains "bootstrap ok" "$bootstrap" '"ok":true'
assert_contains "bootstrap schema" "$bootstrap" '"schemaVersion":2'
assert_contains "bootstrap command schemas" "$bootstrap" '"commandSchemas":'
assert_contains "bootstrap captures create" "$bootstrap" '"id":"captures.create"'
assert_contains "bootstrap recipe schemas" "$bootstrap" '"recipeSchemas":'
assert_contains "bootstrap agent docs" "$bootstrap" '"AGENTS.md"'

valid_command="$(run_json agent validate -- projects create "Agent Draft")"
assert_contains "validate ok" "$valid_command" '"ok":true'
assert_contains "validate valid" "$valid_command" '"valid":true'
assert_contains "validate command id" "$valid_command" '"commandId":"projects.create"'

invalid_command="$(run_json agent validate -- peaks set SideProject --days mon)"
assert_contains "validate invalid ok" "$invalid_command" '"ok":true'
assert_contains "validate invalid" "$invalid_command" '"valid":false'
assert_contains "validate missing flag" "$invalid_command" "Missing required flag --hours."

context="$(run_json context show --limit 10)"
assert_contains "context ok" "$context" '"ok":true'
assert_contains "context counts" "$context" '"counts":'

recipes="$(run_json recipes search --query dry-run)"
assert_contains "recipes ok" "$recipes" '"ok":true'
assert_contains "recipes dry-run project" "$recipes" '"id":"project.archive-dry-run"'

preview="$(run_json_dry projects create "Agent Draft")"
assert_contains "dry-run ok" "$preview" '"ok":true'
assert_contains "dry-run message" "$preview" "Would create project Agent Draft."

projects="$(run_json projects list)"
assert_contains "project list ok" "$projects" '"ok":true'
if [[ "$projects" == *"Agent Draft"* ]]; then
  echo "FAIL: dry-run project create mutated the store" >&2
  echo "$projects" >&2
  exit 1
fi

echo "CLI agent smoke passed"
