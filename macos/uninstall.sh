#!/bin/bash
# Removes the experimental Mod Loader for MacOS from Melvor Idle 2.app.
# Your mods and settings in ~/Library/Application Support/MelvorModLoader are kept.
#
#   bash uninstall.sh
#   bash uninstall.sh "/Applications/Melvor Idle 2.app"

set -euo pipefail

say()  { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

APP=${1:-}
if [ -z "$APP" ]; then
    for candidate in \
        "$HOME/Library/Application Support/Steam/steamapps/common/Melvor Idle 2"/*.app \
        "$HOME/Library/Application Support/Steam/steamapps/common"/*Melvor*.app \
        "/Applications/Melvor Idle 2.app"; do
        if [ -d "$candidate" ]; then APP=$candidate; break; fi
    done
fi

[ -n "$APP" ] || die "Melvor Idle 2.app not found. Pass it: bash uninstall.sh \"/path/to/Melvor Idle 2.app\""
APP=${APP%/}
[ -d "$APP" ] || die "Not a folder: $APP"

MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
EXE_NAME=""
if [ -x /usr/libexec/PlistBuddy ]; then
    EXE_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
        "$APP/Contents/Info.plist" 2>/dev/null || true)
fi
[ -n "$EXE_NAME" ] || EXE_NAME=$(basename "$APP" .app)

if pgrep -f "$MACOS/$EXE_NAME" >/dev/null 2>&1; then
    die "Melvor Idle 2 is running. Quit it, then run this again."
fi

removed=0
if [ -f "$MACOS/override.cfg" ]; then
    rm -f "$MACOS/override.cfg"
    say "Removed Contents/MacOS/override.cfg"
    removed=$((removed + 1))
fi

for base in "$RES" "$MACOS"; do
    [ -d "$base" ] || continue
    for dir in "$base"/data_MelvorModLoader_macos_*; do
        [ -d "$dir" ] || continue
        rm -rf "$dir"
        say "Removed ${dir#$APP/}"
        removed=$((removed + 1))
    done
done

[ "$removed" -gt 0 ] || warn "The loader did not look installed; nothing was removed."

if [ "${MELVOR_SKIP_SIGN:-0}" != "1" ] && command -v codesign >/dev/null 2>&1; then
    say "Re-signing the bundle ad-hoc..."
    if ! codesign --force --deep --sign - "$APP" >/dev/null 2>&1; then
        warn "codesign failed. If macOS refuses to start the game, run:"
        warn "  codesign --force --deep --sign - \"$APP\""
    fi
fi

say ""
say "Done. The game starts unmodded."
say "Mods and settings are still in:"
say "  $HOME/Library/Application Support/MelvorModLoader"
say "Delete that folder yourself if you want them gone too."
