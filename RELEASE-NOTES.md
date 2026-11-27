# Mod Loader for MacOS 1.0.8

An independent mod loader for **Melvor Idle 2**, packaged for macOS on Apple Silicon and Intel.

> **macOS only.** This loader does not support Windows. For Windows, use
> [Melvor Mod Loader by falorfrozen](https://github.com/falorfrozen-cmd/MelvorModLoader).

It implements the same public mod API as Melvor Mod Loader (`IMod`, `ModContext`,
`GameAccess`, `ModWindow`, `Hotkeys`) so existing mod DLLs load unchanged. The
implementation is new; it is not the original loader.

## Changes in 1.0.8

- Updated Mod Viewer to 0.1.13.
- Mod Viewer's Required lock now applies only on macOS, so Windows users can still disable it.

## Changes in 1.0.7

- Added **Backup Saver** as a preinstalled mod. It copies saves after startup and each local
  save, and keeps the five newest dated backups.

## Features

- Loads every DLL under `mods` (flat or one folder deep).
- A broken mod is logged and skipped; the game and other mods keep running.
- Raises `ModContext.Frame` once per rendered frame, paused during offline progress.
- Blue status line at the bottom-left for 15 seconds with the version and mod count,
  fading out at the end.
- **Mods** button or **F1** opens **Mod Viewer** (F2 also works). Mod Viewer is part of the
  loader, cannot be disabled, and is reported as a loader error if it is missing.
- Uses Godot's standard `override.cfg` mechanism. No game file is modified or replaced.
- The macOS package installs inside `Melvor Idle 2.app` and re-signs it ad-hoc; mods,
  settings, and logs stay in `~/Library/Application Support/MelvorModLoader`.
- The macOS package includes **Mod Viewer 0.1.13** and **Backup Saver 0.1.0**.
- Backup Saver keeps the five newest save backups in
  `~/Library/Application Support/MelvorModLoader/backups`.
- Installs with a readable `install.sh` script from Terminal; no unsigned installer `.app`.

## Install (macOS)

There is no installer `.app`. The package uses readable `.command` scripts instead:

1. Quit Melvor Idle 2.
2. Unzip the package.
3. Double-click **Install Mod Loader for MacOS.command**.
4. Start Melvor Idle 2 from Steam.

If macOS blocks the `.command`, right-click it -> **Open**, or run `bash install.sh` in Terminal.
The script finds the game, installs the required Mod Viewer 0.1.13, and re-signs the bundle
ad-hoc. If the game is somewhere else: `bash install.sh "/path/to/Melvor Idle 2.app"`.

## Compatibility

The assembly name and public API names remain `MelvorModLoader` because that is the binary
contract existing mods reference. The product and implementation are Mod Loader for MacOS.

## Package

- `ModLoaderForMacOS-1.0.8-macos.zip` - SHA256
  `228018476C1D532D66C5C801F7DA4A158FBAF9C53564CC7C249E14A38B218C38`

The macOS package is experimental and has not been run on a physical Mac. The loader and
all 14 3am mods compile against this API.

## License

MIT. Melvor Idle 2 is made by Games by Malcs; this is an unofficial fan project and contains
none of the game's files. The .NET runtime in the package is Microsoft's, under the MIT license.
