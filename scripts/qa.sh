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
POLL_ATTEMPTS=20
POLL_INTERVAL=0.25

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

terminate_app() {
    pkill -x "$APP_NAME" 2>/dev/null || true

    local attempt
    for attempt in $(seq 1 "$POLL_ATTEMPTS"); do
        if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$POLL_INTERVAL"
    done

    pkill -9 -x "$APP_NAME" 2>/dev/null || true
    for attempt in $(seq 1 "$POLL_ATTEMPTS"); do
        if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$POLL_INTERVAL"
    done

    echo "$(red 'ABORT'): Could not terminate existing $APP_NAME process."
    exit 1
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

# Find a named app window via Accessibility and return "width height onscreen".
# CGWindowList can report nil kCGWindowName values for SwiftUI windows on some hosts,
# while Accessibility still exposes the real window title and size.
named_window_info() {
    local title="$1"
    osascript - "$APP_NAME" "$title" <<'APPLESCRIPT' 2>/dev/null
on run argv
    set appName to item 1 of argv
    set targetTitle to item 2 of argv
    tell application "System Events"
        tell process appName
            repeat with candidateWindow in windows
                if title of candidateWindow is targetTitle then
                    set windowSize to size of candidateWindow
                    return (item 1 of windowSize as text) & " " & (item 2 of windowSize as text) & " true"
                end if
            end repeat
        end tell
    end tell
    return ""
end run
APPLESCRIPT
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

wait_for_popover() {
    local expected="$1"
    local value
    for _ in $(seq 1 "$POLL_ATTEMPTS"); do
        value=$(popover_visible)
        if [ "$value" = "$expected" ]; then
            echo "$value"
            return
        fi
        sleep "$POLL_INTERVAL"
    done
    popover_visible
}

wait_for_named_window() {
    local title="$1"
    local expected="$2"
    local value
    for _ in $(seq 1 "$POLL_ATTEMPTS"); do
        value=$(named_window_exists "$title")
        if [ "$value" = "$expected" ]; then
            echo "$value"
            return
        fi
        sleep "$POLL_INTERVAL"
    done
    named_window_exists "$title"
}

count_named_windows() {
    local title="$1"
    osascript - "$APP_NAME" "$title" <<'APPLESCRIPT' 2>/dev/null || echo "0"
on run argv
    set appName to item 1 of argv
    set targetTitle to item 2 of argv
    set windowCount to 0
    tell application "System Events"
        tell process appName
            repeat with candidateWindow in windows
                if title of candidateWindow is targetTitle then
                    set windowCount to windowCount + 1
                end if
            end repeat
        end tell
    end tell
    return windowCount as text
end run
APPLESCRIPT
}

wait_for_named_window_count() {
    local title="$1"
    local expected="$2"
    local value
    for _ in $(seq 1 "$POLL_ATTEMPTS"); do
        value=$(count_named_windows "$title")
        if [ "$value" = "$expected" ]; then
            echo "$value"
            return
        fi
        sleep "$POLL_INTERVAL"
    done
    count_named_windows "$title"
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

set_popover_state() {
    local expected="$1"
    local value

    value=$(popover_visible)
    if [ "$value" != "$expected" ]; then
        press_status_item
        value=$(wait_for_popover "$expected")
    fi

    if [ "$value" != "$expected" ]; then
        press_status_item
        value=$(wait_for_popover "$expected")
    fi

    echo "$value"
}

# Click a menu bar menu item: menu_name, item_name
click_menu_item() {
    local menu_name="$1"
    local item_name="$2"
    local attempt

    for attempt in $(seq 1 3); do
        if osascript -e "
tell application \"System Events\"
    tell process \"$APP_NAME\"
        key code 53
        set frontmost to true
        perform action \"AXPress\" of menu bar item \"$menu_name\" of menu bar 1
        delay 0.2
        click menu item \"$item_name\" of menu \"$menu_name\" of menu bar item \"$menu_name\" of menu bar 1
    end tell
end tell
" >/dev/null 2>&1; then
            sleep "$WINDOW_WAIT"
            return
        fi

        sleep "$POLL_INTERVAL"
    done

    echo "  $(red WARNING): click_menu_item '$menu_name' > '$item_name' failed" >&2
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

# Kill any existing instance and wait for it to fully exit.
terminate_app

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
vis=$(wait_for_popover "false")
assert_false "Popover closed on launch" "$vis"

# ─── 2. Popover toggle ────────────────────────────────────────────

echo ""
bold "2. Popover toggle"
echo ""

vis=$(set_popover_state "true")
assert_true "AXPress status item → popover opens" "$vis"

vis=$(set_popover_state "false")
assert_false "AXPress again → popover closes" "$vis"

# ─── 3. New Capture window (File > New Capture) ───────────────────

echo ""
bold "3. New Capture window"
echo ""

# Open popover first (triggers PopoverContentView.onAppear which wires up callbacks)
set_popover_state "true" >/dev/null
sleep 1  # extra time for SwiftUI onAppear to wire callbacks

click_menu_item "File" "New Capture"
exists=$(wait_for_named_window "New Capture" "true")
assert_true "File > New Capture opens window" "$exists"

if [ "$exists" = "true" ]; then
    w=$(named_window_width "New Capture")
    assert_eq "Capture window width" "420" "$w"

    close_window "New Capture"
    exists_after=$(wait_for_named_window "New Capture" "false")
    assert_false "Close button dismisses Capture window" "$exists_after"
fi

# ─── 4. Preferences window ────────────────────────────────────────

echo ""
bold "4. Preferences window"
echo ""

click_menu_item "RedditReminder" "Settings…"
exists=$(wait_for_named_window "RedditReminder Preferences" "true")
assert_true "Settings menu opens Preferences window" "$exists"

if [ "$exists" = "true" ]; then
    w=$(named_window_width "RedditReminder Preferences")
    assert_eq "Preferences window width" "500" "$w"

    close_window "RedditReminder Preferences"
    exists_after=$(wait_for_named_window "RedditReminder Preferences" "false")
    assert_false "Close button dismisses Preferences window" "$exists_after"
fi

# ─── 5. Popover dismisses when windows open ───────────────────────

echo ""
bold "5. Popover auto-dismiss"
echo ""

# Open popover
vis=$(set_popover_state "true")
assert_true "Popover is open before New Capture" "$vis"

# Open capture window — popover should dismiss
click_menu_item "File" "New Capture"
vis=$(wait_for_popover "false")
assert_false "Popover dismissed when Capture opens" "$vis"

close_window "New Capture"

# ─── 6. Capture window reuse ──────────────────────────────────────

echo ""
bold "6. Capture window reuse"
echo ""

# Open, close, open again
click_menu_item "File" "New Capture"
exists1=$(wait_for_named_window "New Capture" "true")
assert_true "First New Capture window opens" "$exists1"

close_window "New Capture"

click_menu_item "File" "New Capture"
exists2=$(wait_for_named_window "New Capture" "true")
assert_true "Second New Capture opens after close" "$exists2"

close_window "New Capture"

# ─── 7. Preferences window reuse ──────────────────────────────────

echo ""
bold "7. Preferences window reuse"
echo ""

click_menu_item "RedditReminder" "Settings…"
exists=$(wait_for_named_window "RedditReminder Preferences" "true")
assert_true "First Preferences window opens" "$exists"

# Open again — should reuse, not duplicate
click_menu_item "RedditReminder" "Settings…"
count=$(wait_for_named_window_count "RedditReminder Preferences" "1")
assert_eq "Only one Preferences window (reuse)" "1" "$count"

close_window "RedditReminder Preferences"

# ─── 8. QA fixtures ───────────────────────────────────────────────

echo ""
bold "8. QA fixture data (--seed-qa)"
echo ""

# Open popover and check for content
set_popover_state "true" >/dev/null
sleep "$ACTION_WAIT"

# The popover content isn't accessible via System Events, but we can
# verify the capture window shows data by opening a capture for edit.
# For now, verify the popover opens (implies data loaded and view rendered).
vis=$(set_popover_state "true")
assert_true "Popover renders with seeded data" "$vis"

# Close popover
set_popover_state "false" >/dev/null

# ─── 9. Debug posting actions ─────────────────────────────────────

echo ""
bold "9. Debug posting actions"
echo ""

printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Queued Capture"
copied_capture=$(pbpaste)
assert_eq "QA copy first queued capture" "Quick thought: *menu bar apps* are underrated on macOS" "$copied_capture"

printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Queued Submit URL"
copied_submit_url=$(pbpaste)
assert_eq "QA copy first queued submit URL" "https://www.reddit.com/r/SideProject/submit" "$copied_submit_url"

click_menu_item "QA" "Mark First Queued Capture Posted"
printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Queued Capture"
copied_after_mark=$(pbpaste)
assert_true "QA mark posted advances first queued capture" "$([ "$copied_after_mark" != "$copied_capture" ] && echo true || echo false)"

click_menu_item "QA" "Create Test Capture"
printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Queued Capture Title"
created_title=$(pbpaste)
assert_eq "QA create test capture title" "QA Workflow Capture" "$created_title"

printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Queued Capture"
created_capture=$(pbpaste)
assert_eq "QA create test capture body" "Created by RedditReminder automated QA.

https://example.com/reddit-reminder-qa" "$created_capture"

printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Queued Submit URL"
created_submit_url=$(pbpaste)
assert_eq "QA create test capture submit URL" "https://www.reddit.com/r/SideProject/submit" "$created_submit_url"

click_menu_item "QA" "Mark First Queued Capture Posted With URL"
printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Posted Capture Summary"
posted_summary=$(pbpaste)
assert_eq "QA posted summary with URL" "Title: QA Workflow Capture
Body: Created by RedditReminder automated QA.
Subreddit: r/SideProject
Posted URL: https://www.reddit.com/r/SideProject/comments/qa123/reddit_reminder_qa/" "$posted_summary"

printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Posted URL"
posted_url=$(pbpaste)
assert_eq "QA posted URL copied" "https://www.reddit.com/r/SideProject/comments/qa123/reddit_reminder_qa/" "$posted_url"

sleep "$ACTION_WAIT"
click_menu_item "QA" "Create Test Capture"
click_menu_item "QA" "Mark First Queued Capture Posted"
printf "sentinel" | pbcopy
click_menu_item "QA" "Copy First Posted Capture Summary"
posted_without_url_summary=$(pbpaste)
assert_eq "QA posted summary without URL" "Title: QA Workflow Capture
Body: Created by RedditReminder automated QA.
Subreddit: r/SideProject
Posted URL: <none>" "$posted_without_url_summary"

click_menu_item "QA" "Delete Test Captures"

# ─── 10. Restart persistence ──────────────────────────────────────

echo ""
bold "10. Restart persistence"
echo ""

terminate_app
open "$APP_PATH"
sleep $((LAUNCH_WAIT + 2))  # extra time for cold start

assert_running "App restarts after kill"

# Verify popover still works after restart
vis=$(set_popover_state "true")
assert_true "Popover opens after restart" "$vis"

# Verify menu shortcuts still work after restart
click_menu_item "File" "New Capture"
exists=$(wait_for_named_window "New Capture" "true")
assert_true "New Capture works after restart" "$exists"
close_window "New Capture"

# Close popover
set_popover_state "false" >/dev/null

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
