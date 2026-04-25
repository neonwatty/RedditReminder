#!/usr/bin/env bash
# RedditReminder QA — automated state-transition tests
# Requires: the app to have been built via `make install` first.
#
# Uses macOS System Events to click at computed coordinates
# and verify window width after each sidebar state transition.
#
# NOTE: This does NOT test the ⌘⇧R global shortcut — that requires
# granting Accessibility permission to RedditReminder manually.

set -euo pipefail

APP_NAME="RedditReminder"
APP_PATH="$HOME/Applications/$APP_NAME.app"
ANIM_WAIT=0.6          # seconds to wait for width animation (0.35s) + margin
LAUNCH_WAIT=2           # seconds to wait after launch

# Expected widths from SidebarConstants (Sources/Utilities/Constants.swift)
W_STRIP=24
W_GLANCE=200
W_BROWSE=320
W_CAPTURE=480
W_SETTINGS=320

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
    "
}

click_at_rel() {
    # Click at a position relative to the window origin.
    # $1 = AppleScript x expression using winX, winW
    # $2 = AppleScript y expression using winY, winH
    local x_expr="$1" y_expr="$2"
    osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set {winX, winY} to position of window 1
                set {winW, winH} to size of window 1
                click at {$x_expr, $y_expr}
            end tell
        end tell
    " >/dev/null
    sleep "$ANIM_WAIT"
}

# Back chevron: top-right of header, fixed offset from window corner
click_back_chevron() { click_at_rel "winX + winW - 21" "winY + 20"; }

# Strip: full-height Button, click center
click_strip()        { click_at_rel "winX + (winW / 2)" "winY + (winH / 2)"; }

# "+ New Capture": pinned to bottom with .padding(10)
click_new_capture()  { click_at_rel "winX + (winW / 2)" "winY + winH - 20"; }

click_cancel() {
    # Cancel button: use accessibility element lookup rather than
    # coordinates. Button order within group 1 is empirical — verify
    # with Accessibility Inspector if the view hierarchy changes.
    local result
    result=$(osascript -e "
        tell application \"System Events\"
            tell process \"$APP_NAME\"
                set grp to group 1 of window 1
                set allBtns to every button of grp
                if (count of allBtns) >= 2 then
                    click item 2 of allBtns
                    return \"clicked\"
                else
                    return \"error: only \" & (count of allBtns) & \" buttons found, expected >= 2\"
                end if
            end tell
        end tell
    ")
    if [[ "$result" == error:* ]]; then
        echo ""
        echo "$(red ERROR): click_cancel: $result" >&2
        exit 1
    fi
    sleep "$ANIM_WAIT"
}

assert_width() {
    local label="$1"
    local expected="$2"
    total=$((total + 1))
    local actual
    actual=$(get_width) || true
    if [ -z "$actual" ]; then
        failed=$((failed + 1))
        printf "  %-45s $(red FAIL)  (could not read window width)\n" "$label"
        return
    fi
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

# ─── pre-flight ────────────────────────────────────────────────────

if ! osascript -e 'tell application "System Events" to return name of first process' >/dev/null 2>&1; then
    echo ""
    red "ERROR"
    echo ": Cannot access System Events."
    echo "  Grant Accessibility permission to your terminal app:"
    echo "  System Settings > Privacy & Security > Accessibility"
    echo ""
    exit 1
fi

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
bold "10. Settings: gear icon"
echo ""
# Click gear icon — positioned left side of header
click_at_rel "winX + 20" "winY + 20"
assert_width   "Gear icon → Settings"              "$W_SETTINGS"

echo ""
bold "11. Settings: back → previous state"
echo ""
click_back_chevron
assert_width   "Back from Settings → Glance"        "$W_GLANCE"

echo ""
bold "12. Restart persistence"
echo ""
click_back_chevron  # Glance → Strip
assert_width   "Pre-restart: Strip"                  "$W_STRIP"

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 2
open "$APP_PATH"
sleep "$LAUNCH_WAIT"

assert_running "App restarts after kill"
assert_width   "Restart in Strip mode (persisted)"   "$W_STRIP"

# Restore to Glance for clean state
click_strip
assert_width   "Back to Glance"                      "$W_GLANCE"

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
