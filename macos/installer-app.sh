#!/bin/bash
# Main executable of "Install Mod Loader for MacOS.app".
# It only drives the UI; the work is done by Contents/Resources/install.sh.

set -u

PKG=$(cd "$(dirname "$0")/../../.." && pwd)
OSAS=/usr/bin/osascript
SUPPORT="$HOME/Library/Application Support/MelvorModLoader"
LOG="$SUPPORT/install.log"

# No GUI session (for example over SSH): fall back to the plain script.
if [ ! -x "$OSAS" ]; then
    "$PKG/install.sh" "$@"
    status=$?
    printf '\nPress Return to close this window...'
    read -r _
    exit $status
fi

say() { "$OSAS" -e "display dialog \"$1\" with title \"Mod Loader for MacOS\" buttons {\"OK\"} default button \"OK\" with icon $2" >/dev/null 2>&1 || true; }

if [ ! -f "$PKG/install.sh" ] || [ ! -d "$PKG/arm64" ]; then
    say "Keep this app in the unzipped Mod Loader for MacOS folder, next to the arm64, x64 and override.cfg items." stop
    exit 1
fi

button=$("$OSAS" -e 'button returned of (display dialog "Mod Loader for MacOS (experimental) for Melvor Idle 2, with Mod Viewer if you do not already have a Mod Viewer. Your saves are not touched." with title "Mod Loader for MacOS" buttons {"Cancel", "Install"} default button "Install" with icon note)' 2>/dev/null) || exit 0
[ "$button" = "Install" ] || exit 0

# A second double-click while the first install is signing should not start a second copy.
mkdir -p "$SUPPORT" 2>/dev/null || true
LOCK="$SUPPORT/.install.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    old=$(cat "$LOCK/pid" 2>/dev/null || true)
    if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
        say "The installer is already running." caution
        exit 1
    fi
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null || exit 1
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

APP=""
for candidate in \
    "$HOME/Library/Application Support/Steam/steamapps/common/Melvor Idle 2"/*.app \
    "$HOME/Library/Application Support/Steam/steamapps/common"/*Melvor*.app \
    "/Applications/Melvor Idle 2.app"; do
    [ -d "$candidate" ] || continue
    [ -f "$candidate/Contents/Info.plist" ] || continue
    APP=$candidate
    break
done

if [ -z "$APP" ]; then
    APP=$("$OSAS" -e 'POSIX path of (choose application with prompt "Select Melvor Idle 2")' 2>/dev/null) || exit 0
    APP=${APP%/}
fi

[ -n "$APP" ] || exit 0

EXE_NAME=""
if [ -x /usr/libexec/PlistBuddy ]; then
    EXE_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist" 2>/dev/null || true)
fi
[ -n "$EXE_NAME" ] || EXE_NAME=$(basename "$APP" .app)

if pgrep -f "$APP/Contents/MacOS/$EXE_NAME" >/dev/null 2>&1; then
    say "Melvor Idle 2 is running. Quit it, then run this installer again." stop
    exit 1
fi

mkdir -p "$SUPPORT" 2>/dev/null || true
"$OSAS" -e 'display notification "Installing the loader..." with title "Mod Loader for MacOS"' >/dev/null 2>&1 || true

if "$PKG/install.sh" "$APP" >"$LOG" 2>&1; then
    button=$("$OSAS" -e 'button returned of (display dialog "Mod Loader for MacOS is installed. Mod Viewer is included unless you already had one. Start Melvor Idle 2 from Steam; the blue loader status line shows at the bottom-left for 15 seconds." with title "Mod Loader for MacOS" buttons {"Later", "Start Game"} default button "Start Game" with icon note)' 2>/dev/null) || button="Later"
    if [ "$button" = "Start Game" ]; then
        open "steam://rungameid/3218350" >/dev/null 2>&1 || true
    fi
    exit 0
fi

button=$("$OSAS" -e 'button returned of (display dialog "Install failed. Show the log to see why." with title "Mod Loader for MacOS" buttons {"Close", "Show Log"} default button "Show Log" with icon stop)' 2>/dev/null) || button="Close"
if [ "$button" = "Show Log" ]; then
    open -a TextEdit "$LOG" >/dev/null 2>&1 || open "$LOG" >/dev/null 2>&1 || true
fi
exit 1
