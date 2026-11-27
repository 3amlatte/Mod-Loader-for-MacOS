# macOS build notes

This folder holds the experimental macOS port: the packaging script, the installer, and the
notes behind the layout. The loader C# code is shared with Windows.

## Why the layout is what it is

Godot's .NET exporter on macOS puts the C# publish output in

```
Melvor Idle 2.app/Contents/Resources/data_<assembly_name>_macos_<arch>/
```

(`modules/mono/editor/GodotTools/.../ExportPlugin.cs` on the Godot side), and `override.cfg`
must sit next to the executable inside `Contents/MacOS/` (Godot's `override.cfg` lookup is the
executable's directory, and on macOS that is the bundle's `Contents/MacOS`).

When `override.cfg` replaces `dotnet/project/assembly_name` with `MelvorModLoader`, Godot looks
for `Contents/Resources/data_MelvorModLoader_macos_<arch>`, which is exactly what the installer
creates. The loader's own `FindGameDataDir` then finds the game's `data_GamesByMalcs.Melvor2_*`
folder next to it, and the logger/mod folder move to
`~/Library/Application Support/MelvorModLoader` so runtime files do not modify the signed bundle.

Arch names come from the export features: `arm64` and `x86_64`. A universal export writes one
data folder per architecture; the installer copies the matching loader for each one it finds.

## Build

```powershell
pwsh ./macos/build-macos.ps1 `
  -GameData "/path/to/data_GamesByMalcs.Melvor2_windows_x86_64" `
  -ModViewerZip "/path/to/melvor-idle-2-mods/dist/ModViewer-0.1.11.zip"
```

`-ModViewerZip` is optional: without it the script looks for the newest
`ModViewer-*.zip` in `../melvor-idle-2-mods/dist` and bundles that. Only one
Mod Viewer is bundled. The installer installs it when no Mod Viewer is already
present, updates an earlier copy from this project (`3am.mod`), and leaves a
third-party Mod Viewer untouched.

The compile-time references are the managed game DLLs. They are the same assemblies on every
platform; only the native engine differs, so the Windows data folder is a valid reference even
when publishing for macOS. Output: `dist-macos/MelvorModLoader-<version>-macos.zip`.

Without PowerShell, publish the two runtimes by hand and copy the results into the package
layout shown below:

```bash
dotnet publish Loader/MelvorModLoader.csproj -c Release -r osx-arm64 \
  -p:GameData="/path/to/data_GamesByMalcs.Melvor2_windows_x86_64" \
  -p:UseAppHost=false -o /tmp/mml-arm64
dotnet publish Loader/MelvorModLoader.csproj -c Release -r osx-x64 \
  -p:GameData="/path/to/data_GamesByMalcs.Melvor2_windows_x86_64" \
  -p:UseAppHost=false -o /tmp/mml-x64
# /tmp/mml-arm64 -> arm64/data_MelvorModLoader_macos_arm64/
# /tmp/mml-x64   -> x64/data_MelvorModLoader_macos_x86_64/
```

Both runtime identifiers are published:

| Folder | Runtime identifier | Godot folder suffix |
| --- | --- | --- |
| `arm64/` | `osx-arm64` | `macos_arm64` |
| `x64/` | `osx-x64` | `macos_x86_64` |

## Package layout

```
MelvorModLoader-<version>-macos/
  Install Mod Loader for MacOS.app/
    Contents/Info.plist
    Contents/PkgInfo
    Contents/MacOS/install-melvor-loader      shell script, Finder-facing UI
    Contents/Resources/README.txt
  Uninstall Mod Loader for MacOS.app/
    Contents/Info.plist
    Contents/PkgInfo
    Contents/MacOS/uninstall-melvor-loader
  arm64/data_MelvorModLoader_macos_arm64/     payload, copied into Contents/Resources
  x64/data_MelvorModLoader_macos_x86_64/
  mods/ModViewer/                             bundled Mod Viewer 0.1.11
  install.sh                                  real work; app and Terminal both call it
  uninstall.sh                                real work
  README-MACOS.txt
  override.cfg
  LICENSE.txt
```

Both `.app` bundles are thin shell-script apps (`CFBundleExecutable` is a bash
script). `installer-app.sh` / `uninstaller-app.sh` only show `osascript` dialogs,
find the game, and call the package-root `install.sh` / `uninstall.sh`. They are
not signed by an Apple Developer certificate, so a downloaded copy needs
right-click → Open once (or Open Anyway in System Settings).

The root `arm64/`, `x64/`, `override.cfg` and `mods/ModViewer` items are the
manual, Windows-style install: copy the loader folders and `override.cfg` into
the `.app`, and `ModViewer` into the mods folder under Application Support.

## Install

```bash
bash install.sh ["/path/to/Melvor Idle 2.app"]
```

The installer:

1. finds the `.app` (default Steam library, then `/Applications`);
2. matches each `data_GamesByMalcs.Melvor2_macos_*` folder to a loader build;
3. copies the loader folders into `Contents/Resources`;
4. writes `Contents/MacOS/override.cfg`;
5. creates `~/Library/Application Support/MelvorModLoader/mods`;
6. copies the bundled `mods/ModViewer` only when no Mod Viewer is installed, or
   updates an earlier copy from this project (folder contains `3am.mod`); it never
   deletes a third-party Mod Viewer or anything in `mods-disabled`;
7. re-signs the bundle ad-hoc (`codesign --force --deep --sign -`), which is required after
   changing a signed `.app` and also removes the hardened runtime so the bundled Microsoft
   .NET runtime can load. If `--deep` fails on the bundle, it signs the main executable with
   the existing entitlements plus `com.apple.security.cs.disable-library-validation` instead.

`uninstall.sh` reverses 3–4 and re-signs again.

## What still needs testing on a real Mac

- That the loader data folder is found by the game's Godot build (the path logic comes from
  Godot's source; the game must be the C# export with a `data_*` folder, not `embed_build_outputs`).
- That the ad-hoc `codesign --deep` pass succeeds on the shipped bundle and Gatekeeper is happy
  when Steam launches it.
- That the game assembly from the macOS export has the same managed API as the Windows reference
  used at compile time (expected: yes, same project and version).
- Steam updates: they replace the bundle, so the installer has to be rerun.

If the game does not start, delete `Contents/MacOS/override.cfg` first; `MelvorModLoader.log`
in Application Support (or the game folder, or `/tmp`) says where it stopped.
