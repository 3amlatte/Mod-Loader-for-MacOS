#!/bin/bash
# Main executable of "Uninstall Mod Loader for MacOS.app".
# It only drives the UI; the work is done by Contents/Resources/uninstall.sh.

set -u

PKG=$(cd "$(dirname "$0")/../../.." && pwd)
OSAS=/usr/bin/osascript
SUPPORT="$HOME/Library/Application Support/MelvorModLoader"
LOG="$SUPPORT/uninstall.log"

if [ ! -x "$OSAS" ]; then
    "$PKG/uninstall.sh" "$@"
    status=$?
    printf '\nPress Return to close this window...'
    read -r _
    exit $status
fi

say() { "$OSAS" -e "display dialog \"$1\" with title \"Mod Loader for MacOS\" buttons {\"OK\"} default button \"OK\" with icon $2" >/dev/null 2>&1 || true; }

if [ ! -f "$PKG/uninstall.sh" ]; then
    say "Keep this app in the unzipped Mod Loader for MacOS folder, next to install.sh and the loader folders." stop
    exit 1
fi

button=$("$OSAS" -e 'button returned of (display dialog "Remove Mod Loader for MacOS from Melvor Idle 2? Your mods and settings stay in Application Support." with title "Mod Loader for MacOS" buttons {"Cancel", "Remove"} default button "Cancel" with icon caution)' 2>/dev/null) || exit 0
[ "$button" = "Remove" ] || exit 0

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
    say "Melvor Idle 2 is running. Quit it, then run this again." stop
    exit 1
fi

mkdir -p "$SUPPORT" 2>/dev/null || true
"$OSAS" -e 'display notification "Removing the loader..." with title "Mod Loader for MacOS"' >/dev/null 2>&1 || true

if "$PKG/uninstall.sh" "$APP" >"$LOG" 2>&1; then
    say "The loader is removed. The game starts unmodded. Mods and settings are still in Application Support." note
    exit 0
fi

button=$("$OSAS" -e 'button returned of (display dialog "Uninstall failed. Show the log to see why." with title "Mod Loader for MacOS" buttons {"Close", "Show Log"} default button "Show Log" with icon stop)' 2>/dev/null) || button="Close"
if [ "$button" = "Show Log" ]; then
    open -a TextEdit "$LOG" >/dev/null 2>&1 || open "$LOG" >/dev/null 2>&1 || true
fi
exit 1
