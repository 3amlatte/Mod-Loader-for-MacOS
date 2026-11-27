#!/bin/bash
# Installs the experimental Mod Loader for MacOS into Melvor Idle 2.app.
#
#   bash install.sh
#   bash install.sh "/Applications/Melvor Idle 2.app"
#   MELVOR_SKIP_SIGN=1 bash install.sh      # do not re-sign the bundle
#
# What it changes inside the .app:
#   Contents/MacOS/override.cfg                         new
#   Contents/Resources/data_MelvorModLoader_macos_*     new
# Nothing else, and no game file is modified.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)

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

[ -n "$APP" ] || die "Melvor Idle 2.app not found. Pass it: bash install.sh \"/path/to/Melvor Idle 2.app\""
APP=${APP%/}
[ -d "$APP" ] || die "Not a folder: $APP"
[ -f "$APP/Contents/Info.plist" ] || die "Not a macOS .app bundle: $APP"

EXE_NAME=""
if [ -x /usr/libexec/PlistBuddy ]; then
    EXE_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
        "$APP/Contents/Info.plist" 2>/dev/null || true)
fi
[ -n "$EXE_NAME" ] || EXE_NAME=$(basename "$APP" .app)

MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
EXE="$MACOS/$EXE_NAME"

[ -d "$MACOS" ] || die "Bundle has no Contents/MacOS folder: $APP"
[ -d "$RES" ]   || die "Bundle has no Contents/Resources folder: $APP"
[ -f "$EXE" ]   || die "Game executable not found: $EXE (is this the game .app?)"

if pgrep -f "$EXE" >/dev/null 2>&1; then
    die "Melvor Idle 2 is running. Quit it, then run this again."
fi

say "Installing Mod Loader for MacOS into:"
say "  $APP"
say ""

installed=0
for base in "$RES" "$MACOS"; do
    [ -d "$base" ] || continue
    for game_data in "$base"/data_GamesByMalcs.Melvor2_*; do
        [ -d "$game_data" ] || continue
        [ -f "$game_data/GamesByMalcs.Melvor2.dll" ] || continue

        name=$(basename "$game_data")
        suffix=${name#data_GamesByMalcs.Melvor2_}
        [ "$suffix" = "$name" ] && continue

        case "$suffix" in
            macos_arm64)  arch=arm64 ;;
            macos_x86_64) arch=x64   ;;
            *) warn "Skipping unknown game data folder: $name"; continue ;;
        esac

        src="$HERE/$arch/data_MelvorModLoader_$suffix"
        if [ ! -d "$src" ]; then
            warn "This package has no $arch loader (expected $src); skipping $suffix"
            continue
        fi

        dest="$base/data_MelvorModLoader_$suffix"
        say "  $arch loader -> ${dest#$APP/}"
        rm -rf "$dest"
        cp -R "$src" "$dest"
        installed=$((installed + 1))
    done
done

[ "$installed" -gt 0 ] || die "No C# data folder (data_GamesByMalcs.Melvor2_macos_*) found. Is this the Steam C# build of Melvor Idle 2?"

cat > "$MACOS/override.cfg" <<'EOF'
[dotnet]

project/assembly_name="MelvorModLoader"
EOF
say "  override.cfg -> Contents/MacOS/override.cfg"

SUPPORT="$HOME/Library/Application Support/MelvorModLoader"
MODS="$SUPPORT/mods"
mkdir -p "$MODS"
if [ -f "$HERE/README-MACOS.txt" ]; then
    cp "$HERE/README-MACOS.txt" "$SUPPORT/README.txt" 2>/dev/null || true
fi
say "  mods folder  -> $MODS"

# Mod Viewer ships with this package. Install it only when no Mod Viewer is present,
# and update only an earlier copy from this project (its folder has 3am.mod).
# Never delete a third-party Mod Viewer, a disabled one, or anything else in mods.
VIEWER_SRC="$HERE/mods/ModViewer"
if [ -d "$VIEWER_SRC" ]; then
    viewer_flat=$(find "$MODS" -maxdepth 1 -iname 'modviewer.dll' -print 2>/dev/null | head -n 1)
    viewer_other=$(find "$MODS" -mindepth 2 -maxdepth 2 -iname 'modviewer.dll' \
        ! -path "$MODS/ModViewer/ModViewer.dll" -print 2>/dev/null | head -n 1)

    if [ -n "$viewer_flat" ] || [ -n "$viewer_other" ]; then
        say "  Mod Viewer: another ModViewer is already installed; left it alone"
    elif [ -d "$MODS/ModViewer" ] && [ ! -f "$MODS/ModViewer/3am.mod" ]; then
        say "  Mod Viewer: an existing ModViewer was left untouched"
    else
        # No Mod Viewer, or our own earlier copy: install/update the bundled one.
        rm -rf "$MODS/ModViewer" 2>/dev/null || true
        mkdir -p "$MODS/ModViewer"
        cp -R "$VIEWER_SRC/." "$MODS/ModViewer/"
        say "  Mod Viewer   -> $MODS/ModViewer"
    fi
else
    warn "The bundled Mod Viewer was not found; installing the loader without it."
fi

# Any change inside a signed .app invalidates Apple's signature. Re-signing the bundle
# ad-hoc recomputes it and drops the hardened runtime, which also lets the bundled
# Microsoft .NET runtime load. The game's own binary and data are not changed.
if [ "${MELVOR_SKIP_SIGN:-0}" = "1" ]; then
    say "  codesign: skipped (MELVOR_SKIP_SIGN=1)"
else
    if command -v codesign >/dev/null 2>&1; then
        xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
        say "  codesign: re-signing the bundle ad-hoc (may take a minute)..."
        if ! codesign --force --deep --sign - "$APP" >/dev/null 2>&1; then
            # Some bundles do not survive --deep. Signing just the main executable with
            # disable-library-validation still lets the bundled .NET runtime load, and keeps
            # the JIT entitlements the Godot Mono export needs.
            warn "Whole-bundle signing failed; re-signing the main executable instead."
            sign_tmp=$(mktemp -d 2>/dev/null || echo "/tmp/melvormodloader-sign.$$")
            entitlement_file="$sign_tmp/entitlements.plist"
            if codesign -d --entitlements :- "$EXE" > "$entitlement_file" 2>/dev/null && [ -s "$entitlement_file" ]; then
                /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" \
                    "$entitlement_file" 2>/dev/null || \
                    /usr/libexec/PlistBuddy -c "Set :com.apple.security.cs.disable-library-validation true" \
                    "$entitlement_file" 2>/dev/null || true
            else
                cat > "$entitlement_file" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF
            fi
            if ! codesign --force --options runtime --entitlements "$entitlement_file" --sign - "$EXE" >/dev/null 2>&1; then
                warn "codesign failed. The loader is installed; if macOS refuses to start the game, run:"
                warn "  codesign --force --deep --sign - \"$APP\""
            fi
            rm -rf "$sign_tmp"
        fi
    else
        warn "codesign not found; the bundle signature is now invalid (the game usually still starts)."
    fi
fi

say ""
say "Done. Start Melvor Idle 2 from Steam."
say "  Log:  $SUPPORT/ModLoaderForMacOS.log"
say "  Mods: $MODS"
say ""
say "Install a mod by extracting its zip into:"
say "  $SUPPORT"
say "(the zip contains a mods/ folder, so it lands in $MODS)"
say ""
say "Experimental build: if the game does not start, run uninstall.sh."
