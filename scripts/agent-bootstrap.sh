#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI="$REPO_ROOT/build/Build/Products/Debug/redditreminder"

needs_build=false
if [[ ! -x "$CLI" ]]; then
  needs_build=true
elif find "$REPO_ROOT/CLI" "$REPO_ROOT/Sources" "$REPO_ROOT/Resources" \
  "$REPO_ROOT/project.yml" "$REPO_ROOT/Makefile" -newer "$CLI" -print -quit \
  | grep -q .
then
  needs_build=true
fi

if [[ "$needs_build" == true ]]; then
  echo "Building redditreminder CLI..." >&2
  make -C "$REPO_ROOT" build-cli >&2
fi

echo "Running: $CLI --json agent bootstrap" >&2
exec "$CLI" --json agent bootstrap
