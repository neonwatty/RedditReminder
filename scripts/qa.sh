#!/usr/bin/env bash
# RedditReminder QA — automated state-transition tests
# Requires: the app to have been built via `make install` first.
#
# Uses macOS Accessibility (System Events) to click SwiftUI Buttons
# and verifies window width matches expected sidebar state.
#
# NOTE: This does NOT test the ⌘⇧R global shortcut — that requires
# granting Accessibility permission to RedditReminder manually.

set -euo pipefail

APP_NAME="RedditReminder"
APP_PATH="$HOME/Applications/$APP_NAME.app"
ANIM_WAIT=0.6          # seconds to wait for width animation (0.35s) + margin
LAUNCH_WAIT=2           # seconds to wait after launch

# Expected widths from Constants.swift
W_STRIP=24
W_GLANCE=200
W_BROWSE=320
W_CAPTURE=480

passed=0
failed=0
total=0

# ─── helpers ───────────────────────────────────────────────────────

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

get_width() {
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set {w, h} to size of window 1
                return w as integer
            end tell
        end tell
    " 2>/dev/null
}

get_pos_size() {
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set {x, y} to position of window 1
                set {w, h} to size of window 1
                return (x as text) & \",\" & (y as text) & \",\" & (w as text) & \",\" & (h as text)
            end tell
        end tell
    " 2>/dev/null
}

click_back_chevron() {
    # The back chevron is button 1 inside the header group — the first button
    # in the window, positioned top-right with padding(.horizontal, 14).
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set {winX, winY} to position of window 1
                set {winW, winH} to size of window 1
                click at {winX + winW - 21, winY + 20}
            end tell
        end tell
    " >/dev/null 2>&1
    sleep "$ANIM_WAIT"
}

click_strip() {
    # The strip is a full-height Button. Click its center.
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set {winX, winY} to position of window 1
                set {winW, winH} to size of window 1
                click at {winX + (winW / 2), winY + (winH / 2)}
            end tell
        end tell
    " >/dev/null 2>&1
    sleep "$ANIM_WAIT"
}

click_new_capture() {
    # "+ New Capture" is the last button in the window, pinned to bottom.
    # In both Glance and Browse it sits at padding(10/10) from bottom.
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set {winX, winY} to position of window 1
                set {winW, winH} to size of window 1
                click at {winX + (winW / 2), winY + winH - 20}
            end tell
        end tell
    " >/dev/null 2>&1
    sleep "$ANIM_WAIT"
}

click_cancel() {
    # Cancel button coordinates are fragile across resolutions.
    # Instead, use accessibility to find it: it is button 2 in the
    # main group (button 1 is the back chevron).
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set grp to group 1 of window 1
                set allBtns to every button of grp
                -- Button order: 1=back chevron, 2=Cancel, 3=Add to Queue
                if (count of allBtns) >= 2 then
                    click item 2 of allBtns
                end if
            end tell
        end tell
    " >/dev/null 2>&1
    sleep "$ANIM_WAIT"
}

assert_width() {
    local label="$1"
    local expected="$2"
    total=$((total + 1))
    local actual
    actual=$(get_width)
    if [ "$actual" -eq "$expected" ]; then
        passed=$((passed + 1))
        printf "  %-45s $(green PASS)  (%dpx)\n" "$label" "$actual"
    else
        failed=$((failed + 1))
        printf "  %-45s $(red FAIL)  (expected %dpx, got %dpx)\n" "$label" "$expected" "$actual"
    fi
}

assert_running() {
    total=$((total + 1))
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        passed=$((passed + 1))
        printf "  %-45s $(green PASS)\n" "$1"
    else
        failed=$((failed + 1))
        printf "  %-45s $(red FAIL)  (process not found)\n" "$1"
        echo ""
        echo "$(red 'ABORT'): App not running. Cannot continue."
        exit 1
    fi
}

# ─── setup ─────────────────────────────────────────────────────────

echo ""
bold "RedditReminder QA"
echo ""
echo "─────────────────────────────────────────────────"

# Kill any existing instance
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

# Launch
echo "  Launching $APP_NAME..."
open "$APP_PATH"
sleep "$LAUNCH_WAIT"

# ─── tests ─────────────────────────────────────────────────────────

echo ""
bold "1. Launch"
echo ""
assert_running "App is running"
assert_width   "Starts in Glance mode"              "$W_GLANCE"

echo ""
bold "2. Step down: Glance → Strip"
echo ""
click_back_chevron
assert_width   "Back chevron → Strip"                "$W_STRIP"

echo ""
bold "3. Expand: Strip → Glance"
echo ""
click_strip
assert_width   "Click strip → Glance"               "$W_GLANCE"

echo ""
bold "4. New Capture: Glance → Capture"
echo ""
click_new_capture
assert_width   "New Capture → Capture"               "$W_CAPTURE"

echo ""
bold "5. Cancel: Capture → Browse"
echo ""
click_cancel
assert_width   "Cancel → Browse"                     "$W_BROWSE"

echo ""
bold "6. Step down: Browse → Glance"
echo ""
click_back_chevron
assert_width   "Back chevron → Glance"               "$W_GLANCE"

echo ""
bold "7. Step down: Glance → Strip"
echo ""
click_back_chevron
assert_width   "Back chevron → Strip"                "$W_STRIP"

echo ""
bold "8. Expand + New Capture: Strip → Glance → Capture"
echo ""
click_strip
assert_width   "Click strip → Glance"               "$W_GLANCE"
click_new_capture
assert_width   "New Capture → Capture"               "$W_CAPTURE"

echo ""
bold "9. Full step-down: Capture → Browse → Glance → Strip"
echo ""
click_back_chevron
assert_width   "Back chevron → Browse"               "$W_BROWSE"
click_back_chevron
assert_width   "Back chevron → Glance"               "$W_GLANCE"
click_back_chevron
assert_width   "Back chevron → Strip"                "$W_STRIP"

echo ""
bold "10. Restart persistence"
echo ""
click_strip    # back to Glance so we can verify it restarts at Glance
assert_width   "Pre-restart: Glance"                 "$W_GLANCE"

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 2
open "$APP_PATH"
sleep "$LAUNCH_WAIT"

assert_running "App restarts after kill"
assert_width   "Restart in Glance mode"              "$W_GLANCE"

# ─── summary ───────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────────────────────"
if [ "$failed" -eq 0 ]; then
    green "ALL $total TESTS PASSED"
    echo ""
else
    red "$failed/$total TESTS FAILED"
    echo ""
fi
echo ""

# Clean up — leave app running
exit "$failed"
