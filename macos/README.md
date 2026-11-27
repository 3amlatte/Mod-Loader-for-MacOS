# macOS packaging notes

This folder holds the experimental macOS port: the packaging script, the install script, and
the notes behind the layout.

## Why the layout is what it is

Godot's .NET exporter on macOS puts the C# publish output in

```
Melvor Idle 2.app/Contents/Resources/data_<assembly_name>_macos_<arch>/
```

(`modules/mono/editor/GodotTools/.../ExportPlugin.cs` on the Godot side), and `override.cfg`
must sit next to the executable inside `Contents/MacOS/` (Godot's `override.cfg` lookup is the
executable's directory, and on macOS that is the bundle's `Contents/MacOS`).

When `override.cfg` replaces `dotnet/project/assembly_name` with `MelvorModLoader`, Godot looks
for `Contents/Resources/data_MelvorModLoader_macos_<arch>`, which is exactly what the install
script creates. The loader's own `FindGameDataDir` then finds the game's `data_GamesByMalcs.Melvor2_*`
folder next to it, and the logger/mod folder move to
`~/Library/Application Support/MelvorModLoader` so runtime files do not modify the signed bundle.

Arch names come from the export features: `arm64` and `x86_64`. A universal export writes one
data folder per architecture; the install script copies the matching loader for each one it finds.

`-ModViewerZip` is optional: without it the packaging script looks for the newest
`ModViewer-*.zip` in `../melvor-idle-2-mods/dist` and bundles that. Only one
Mod Viewer is bundled and required. The install script always installs or updates
`mods/ModViewer`; it warns if another ModViewer exists under a different folder.

Both runtime identifiers are packaged:

| Folder | Runtime identifier | Godot folder suffix |
| --- | --- | --- |
| `arm64/` | `osx-arm64` | `macos_arm64` |
| `x64/` | `osx-x64` | `macos_x86_64` |

## Package layout

```
ModLoaderForMacOS-<version>-macos/
  arm64/data_MelvorModLoader_macos_arm64/     payload, copied into Contents/Resources
  x64/data_MelvorModLoader_macos_x86_64/
  mods/ModViewer/                             bundled Mod Viewer 0.1.12
  install.sh                                  copies and re-signs; the default install
  uninstall.sh                                removes the loader and re-signs
  README-MACOS.txt
  override.cfg
  LICENSE.txt
```

There is no installer `.app`. Opening an unsigned app is the exact Gatekeeper
prompt this package avoids. `install.sh` is readable text and is run explicitly
from Terminal.

## Install

This is the default and recommended install path:

```bash
bash install.sh ["/path/to/Melvor Idle 2.app"]
```

No `.app` is opened. The script:

1. finds the `.app` (default Steam library, then `/Applications`);
2. matches each `data_GamesByMalcs.Melvor2_macos_*` folder to a loader folder;
3. copies the loader folders into `Contents/Resources`;
4. writes `Contents/MacOS/override.cfg`;
5. creates `~/Library/Application Support/MelvorModLoader/mods`;
6. always installs the required bundled `mods/ModViewer` and warns if another
   ModViewer exists under a different folder;
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
- That the game assembly from the macOS export has the same managed API as the compile-time reference
  used at compile time (expected: yes, same project and version).
- Steam updates: they replace the bundle, so the install script has to be rerun.

If the game does not start, delete `Contents/MacOS/override.cfg` first; `MelvorModLoader.log`
in Application Support (or the game folder, or `/tmp`) says where it stopped.
