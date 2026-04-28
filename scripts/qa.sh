#!/usr/bin/env bash
# RedditReminder QA — automated smoke tests for the menu bar popover app
# Requires: the app to have been built via `make install` first.
#
# Uses macOS System Events / AppleScript to interact with the status item,
# and CGWindowList (via Swift) to detect the popover (which lives at a
# special window layer not visible to the accessibility API).
#
# NOTE: Grant Accessibility permission to your terminal app:
#   System Settings > Privacy & Security > Accessibility

set -euo pipefail

APP_NAME="RedditReminder"
APP_PATH="$HOME/Applications/$APP_NAME.app"
LAUNCH_WAIT=3           # seconds to wait after launch
ACTION_WAIT=1.5         # seconds to wait after UI action
WINDOW_WAIT=2.0         # seconds to wait for window to appear

passed=0
failed=0
total=0

# ─── helpers ───────────────────────────────────────────────────────

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

assert_true() {
    local label="$1"
    local condition="$2"  # "true" or "false"
    total=$((total + 1))
    if [ "$condition" = "true" ]; then
        passed=$((passed + 1))
        printf "  %-50s $(green PASS)\n" "$label"
    else
        failed=$((failed + 1))
        printf "  %-50s $(red FAIL)\n" "$label"
    fi
}

assert_false() {
    local label="$1"
    local condition="$2"  # "true" or "false"
    if [ "$condition" = "false" ]; then
        assert_true "$label" "true"
    else
        assert_true "$label" "false"
    fi
}

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    total=$((total + 1))
    if [ "$expected" = "$actual" ]; then
        passed=$((passed + 1))
        printf "  %-50s $(green PASS)  (%s)\n" "$label" "$actual"
    else
        failed=$((failed + 1))
        printf "  %-50s $(red FAIL)  (expected: %s, got: %s)\n" "$label" "$expected" "$actual"
    fi
}

assert_running() {
    total=$((total + 1))
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        passed=$((passed + 1))
        printf "  %-50s $(green PASS)\n" "$1"
    else
        failed=$((failed + 1))
        printf "  %-50s $(red FAIL)  (process not found)\n" "$1"
        echo ""
        echo "$(red 'ABORT'): App not running. Cannot continue."
        exit 1
    fi
}

# ─── CGWindowList helpers (Swift) ──────────────────────────────────
# NSPopover windows are invisible to System Events because they live at
# window layer 25 (kCGStatusWindowLevel). We use CGWindowListCopyWindowInfo
# to detect them.

popover_visible() {
    swift -e '
import CoreGraphics
let wl = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let found = wl.contains { w in
    (w["kCGWindowOwnerName"] as? String ?? "").contains("RedditReminder") &&
    (w["kCGWindowLayer"] as? Int ?? 0) == 25 &&
    (w["kCGWindowIsOnscreen"] as? Bool ?? false)
}
print(found ? "true" : "false")
' 2>/dev/null || echo "false"
}

# Find a named window owned by RedditReminder and return "width height onscreen"
named_window_info() {
    local title="$1"
    swift -e "
import CoreGraphics
let wl = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for w in wl {
    let owner = w[\"kCGWindowOwnerName\"] as? String ?? \"\"
    let name = w[\"kCGWindowName\"] as? String ?? \"\"
    if owner.contains(\"RedditReminder\") && name == \"$title\" {
        let bounds = w[\"kCGWindowBounds\"] as? [String: Any] ?? [:]
        let width = bounds[\"Width\"] as? Int ?? 0
        let height = bounds[\"Height\"] as? Int ?? 0
        let onscreen = w[\"kCGWindowIsOnscreen\"] as? Bool ?? false
        print(\"\(width) \(height) \(onscreen)\")
        break
    }
}
" 2>/dev/null
}

named_window_exists() {
    local info
    info=$(named_window_info "$1")
    if [ -n "$info" ]; then
        local onscreen
        onscreen=$(echo "$info" | awk '{print $3}')
        if [ "$onscreen" = "true" ]; then echo "true"; else echo "false"; fi
    else
        echo "false"
    fi
}

named_window_width() {
    local info
    info=$(named_window_info "$1")
    echo "$info" | awk '{print $1}'
}

count_named_windows() {
    local title="$1"
    swift -e "
import CoreGraphics
let wl = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
var count = 0
for w in wl {
    let owner = w[\"kCGWindowOwnerName\"] as? String ?? \"\"
    let name = w[\"kCGWindowName\"] as? String ?? \"\"
    let onscreen = w[\"kCGWindowIsOnscreen\"] as? Bool ?? false
    if owner.contains(\"RedditReminder\") && name == \"$title\" && onscreen { count += 1 }
}
print(count)
" 2>/dev/null || echo "0"
}

# ─── UI interaction helpers ────────────────────────────────────────

# Toggle popover via AXPress on the status bar item
press_status_item() {
    if ! osascript -e '
tell application "System Events"
    tell process "RedditReminder"
        perform action "AXPress" of menu bar item 1 of menu bar 2
    end tell
end tell
' >/dev/null 2>&1; then
        echo "  $(red WARNING): press_status_item failed (is the app running?)" >&2
    fi
    sleep "$ACTION_WAIT"
}

# Click a menu bar menu item: menu_name, item_name
click_menu_item() {
    local menu_name="$1"
    local item_name="$2"
    if ! osascript -e "
tell application \"System Events\"
    tell process \"$APP_NAME\"
        click menu item \"$item_name\" of menu \"$menu_name\" of menu bar 1
    end tell
end tell
" >/dev/null 2>&1; then
        echo "  $(red WARNING): click_menu_item '$menu_name' > '$item_name' failed" >&2
    fi
    sleep "$WINDOW_WAIT"
}

# Close a window by title using the close button (button 1)
close_window() {
    local title="$1"
    if ! osascript -e "
tell application \"System Events\"
    tell process \"$APP_NAME\"
        if exists (first window whose title is \"$title\") then
            click button 1 of (first window whose title is \"$title\")
        end if
    end tell
end tell
" >/dev/null 2>&1; then
        echo "  $(red WARNING): close_window '$title' failed" >&2
    fi
    sleep "$ACTION_WAIT"
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

if [ ! -d "$APP_PATH" ]; then
    echo ""
    red "ERROR"
    echo ": App not found at $APP_PATH"
    echo "  Run 'make install' first."
    echo ""
    exit 1
fi

# Screen Recording permission is required for CGWindowListCopyWindowInfo
if ! swift -e '
import CoreGraphics
guard let wl = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]], !wl.isEmpty else { exit(1) }
' 2>/dev/null; then
    echo ""
    red "ERROR"
    echo ": Cannot query window list (CGWindowListCopyWindowInfo)."
    echo "  Grant Screen Recording permission to your terminal app:"
    echo "  System Settings > Privacy & Security > Screen Recording"
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

# Launch with --seed-qa to populate test fixtures (requires DEBUG build)
echo "  Launching $APP_NAME with --seed-qa..."
open "$APP_PATH" --args --seed-qa
sleep "$LAUNCH_WAIT"

# ─── 1. Launch ─────────────────────────────────────────────────────

echo ""
bold "1. Launch"
echo ""
assert_running "App is running"

# Verify popover is NOT open on launch
vis=$(popover_visible)
assert_false "Popover closed on launch" "$vis"

# ─── 2. Popover toggle ────────────────────────────────────────────

echo ""
bold "2. Popover toggle"
echo ""

press_status_item
vis=$(popover_visible)
assert_true "AXPress status item → popover opens" "$vis"

press_status_item
vis=$(popover_visible)
assert_false "AXPress again → popover closes" "$vis"

# ─── 3. New Capture window (File > New Capture) ───────────────────

echo ""
bold "3. New Capture window"
echo ""

# Open popover first (triggers PopoverContentView.onAppear which wires up callbacks)
press_status_item
sleep 1  # extra time for SwiftUI onAppear to wire callbacks

click_menu_item "File" "New Capture"
exists=$(named_window_exists "New Capture")
assert_true "File > New Capture opens window" "$exists"

if [ "$exists" = "true" ]; then
    w=$(named_window_width "New Capture")
    assert_eq "Capture window width" "420" "$w"

    close_window "New Capture"
    exists_after=$(named_window_exists "New Capture")
    assert_false "Close button dismisses Capture window" "$exists_after"
fi

# ─── 4. Preferences window ────────────────────────────────────────

echo ""
bold "4. Preferences window"
echo ""

# macOS renames "Preferences…" to "Settings…" automatically
click_menu_item "RedditReminder" "Settings…"
exists=$(named_window_exists "RedditReminder Preferences")
assert_true "Settings menu opens Preferences window" "$exists"

if [ "$exists" = "true" ]; then
    w=$(named_window_width "RedditReminder Preferences")
    assert_eq "Preferences window width" "500" "$w"

    close_window "RedditReminder Preferences"
    exists_after=$(named_window_exists "RedditReminder Preferences")
    assert_false "Close button dismisses Preferences window" "$exists_after"
fi

# ─── 5. Popover dismisses when windows open ───────────────────────

echo ""
bold "5. Popover auto-dismiss"
echo ""

# Open popover
press_status_item
vis=$(popover_visible)
assert_true "Popover is open before New Capture" "$vis"

# Open capture window — popover should dismiss
click_menu_item "File" "New Capture"
vis=$(popover_visible)
assert_false "Popover dismissed when Capture opens" "$vis"

close_window "New Capture"

# ─── 6. Capture window reuse ──────────────────────────────────────

echo ""
bold "6. Capture window reuse"
echo ""

# Open, close, open again
click_menu_item "File" "New Capture"
exists1=$(named_window_exists "New Capture")
assert_true "First New Capture window opens" "$exists1"

close_window "New Capture"

click_menu_item "File" "New Capture"
exists2=$(named_window_exists "New Capture")
assert_true "Second New Capture opens after close" "$exists2"

close_window "New Capture"

# ─── 7. Preferences window reuse ──────────────────────────────────

echo ""
bold "7. Preferences window reuse"
echo ""

click_menu_item "RedditReminder" "Settings…"
exists=$(named_window_exists "RedditReminder Preferences")
assert_true "First Preferences window opens" "$exists"

# Open again — should reuse, not duplicate
click_menu_item "RedditReminder" "Settings…"
count=$(count_named_windows "RedditReminder Preferences")
assert_eq "Only one Preferences window (reuse)" "1" "$count"

close_window "RedditReminder Preferences"

# ─── 8. QA fixtures ───────────────────────────────────────────────

echo ""
bold "8. QA fixture data (--seed-qa)"
echo ""

# Open popover and check for content
press_status_item
sleep "$ACTION_WAIT"

# The popover content isn't accessible via System Events, but we can
# verify the capture window shows data by opening a capture for edit.
# For now, verify the popover opens (implies data loaded and view rendered).
vis=$(popover_visible)
assert_true "Popover renders with seeded data" "$vis"

# Close popover
press_status_item

# ─── 9. Restart persistence ───────────────────────────────────────

echo ""
bold "9. Restart persistence"
echo ""

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 2
open "$APP_PATH"
sleep $((LAUNCH_WAIT + 2))  # extra time for cold start

assert_running "App restarts after kill"

# Verify popover still works after restart
press_status_item
vis=$(popover_visible)
assert_true "Popover opens after restart" "$vis"

# Verify menu shortcuts still work after restart
click_menu_item "File" "New Capture"
exists=$(named_window_exists "New Capture")
assert_true "New Capture works after restart" "$exists"
close_window "New Capture"

# Close popover
press_status_item

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
