# Mod Loader for MacOS 1.0.3

An independent mod loader for **Melvor Idle 2**, packaged for macOS on Apple Silicon and Intel.

> **macOS only.** This loader does not support Windows. For Windows, use
> [Melvor Mod Loader by falorfrozen](https://github.com/falorfrozen-cmd/MelvorModLoader).

It implements the same public mod API as Melvor Mod Loader (`IMod`, `ModContext`,
`GameAccess`, `ModWindow`, `Hotkeys`) so existing mod DLLs load unchanged. The
implementation is new; it is not the original loader.

## Changes in 1.0.3

- Removed the unsigned installer and uninstaller `.app` bundles.
- The default install is now the readable Terminal script: `bash install.sh`.
- Removed the public build instructions.

## Changes in 1.0.2

- Moved the startup status line from the top-left to the bottom-left.
- Changed it from green to blue and gave it an outline so it stays readable over the game.
- Added a short fade-out at the end of the 15 seconds.

## Features

- Loads every DLL under `mods` (flat or one folder deep).
- A broken mod is logged and skipped; the game and other mods keep running.
- Raises `ModContext.Frame` once per rendered frame, paused during offline progress.
- Blue status line at the bottom-left for 15 seconds with the version and mod count,
  fading out at the end.
- **Mods** button in the game's top bar (or F1): lists every mod panel, lets players
  change or switch off its key, and stores choices in `hotkeys.json`. This is the loader's
  panel/hotkey menu, not Mod Viewer. Mod Viewer is a separate mod included in the package;
  it lists installed mods and opens with F2.
- Uses Godot's standard `override.cfg` mechanism. No game file is modified or replaced.
- The macOS package installs inside `Melvor Idle 2.app` and re-signs it ad-hoc; mods,
  settings, and logs stay in `~/Library/Application Support/MelvorModLoader`.
- The macOS package includes **Mod Viewer 0.1.11**.
- Installs with a readable `install.sh` script from Terminal; no unsigned installer `.app`.
- No Merchant or Multitask code/files.

## Install (macOS)

There is no installer app, so there is no unsigned `.app` to open. Install from Terminal:

1. Quit Melvor Idle 2.
2. Unzip the package.
3. Open Terminal in the unzipped folder and run `bash install.sh`.
4. Start Melvor Idle 2 from Steam.

The script finds the game, installs the loader and Mod Viewer when needed, and re-signs the
bundle ad-hoc. If the game is somewhere else:
`bash install.sh "/path/to/Melvor Idle 2.app"`.

## Compatibility

The assembly name and public API names remain `MelvorModLoader` because that is the binary
contract existing mods reference. The product and implementation are Mod Loader for MacOS.

## Package

- `ModLoaderForMacOS-1.0.3-macos.zip` - SHA256
  `EBFA15A5104649F449E9FC1477A2FD93D723E9AAFFD83B1F15AC4B6367E07A89`

The macOS package is experimental and has not been run on a physical Mac. The loader and
all 14 3am mods compile against this API.

## License

MIT. Melvor Idle 2 is made by Games by Malcs; this is an unofficial fan project and contains
none of the game's files. The .NET runtime in the package is Microsoft's, under the MIT license.
