#!/usr/bin/env bash

set -euo pipefail

BASELINE_FILE="scripts/swift-format-warning-baseline.txt"

if [ ! -f "$BASELINE_FILE" ]; then
  echo "Missing swift-format baseline: $BASELINE_FILE" >&2
  exit 1
fi

baseline="$(tr -d '[:space:]' < "$BASELINE_FILE")"
if ! [[ "$baseline" =~ ^[0-9]+$ ]]; then
  echo "Invalid swift-format baseline in $BASELINE_FILE: $baseline" >&2
  exit 1
fi

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

swift-format lint --recursive Sources Tests 2>&1 | tee "$output_file"

warning_count="$(grep -c "warning:" "$output_file" || true)"
echo "swift-format warnings: $warning_count (baseline: $baseline)"

if [ "$warning_count" -gt "$baseline" ]; then
  echo "swift-format warning count increased. Run swift-format or lower the baseline with the cleanup." >&2
  exit 1
fi
