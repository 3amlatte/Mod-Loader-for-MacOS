# Mod Loader for MacOS 1.0.1

An independent mod loader for **Melvor Idle 2**, packaged for macOS on Apple Silicon and Intel.

> **macOS only.** This loader does not support Windows. For Windows, use
> [Melvor Mod Loader by falorfrozen](https://github.com/falorfrozen-cmd/MelvorModLoader).

It implements the same public mod API as Melvor Mod Loader (`IMod`, `ModContext`,
`GameAccess`, `ModWindow`, `Hotkeys`) so existing mod DLLs load unchanged. The
implementation is new; it is not the original loader.

## Features

- Loads every DLL under `mods` (flat or one folder deep).
- A broken mod is logged and skipped; the game and other mods keep running.
- Raises `ModContext.Frame` once per rendered frame, paused during offline progress.
- Green loader line for 15 seconds with the version and mod count.
- **Mods** button in the game's top bar (or F1): lists every mod panel, lets players
  change or switch off its key, and stores choices in `hotkeys.json`.
- Uses Godot's standard `override.cfg` mechanism. No game file is modified or replaced.
- The macOS package installs inside `Melvor Idle 2.app` and re-signs it ad-hoc; mods,
  settings, and logs stay in `~/Library/Application Support/MelvorModLoader`.
- The macOS package includes **Mod Viewer 0.1.11**.
- No Merchant or Multitask code/files.

## Install (macOS)

1. Quit Melvor Idle 2.
2. Unzip the package.
3. Double-click **Install Mod Loader for MacOS.app**.
4. If macOS cannot verify the app, right-click it -> Open -> Open, or use System Settings ->
   Privacy & Security -> Open Anyway.
5. Click Install, then Start Game.

## Compatibility

The assembly name and public API names remain `MelvorModLoader` because that is the binary
contract existing mods reference. The product and implementation are Mod Loader for MacOS.

## Package

- `ModLoaderForMacOS-1.0.1-macos.zip` - SHA256
  `23A22474C5AA644F06C16B65042E5A2F89CAF9020459AB3CB244CC9D11F4F32A`

The macOS package is experimental and has not been run on a physical Mac. The loader and
all 14 3am mods compile against this API.

## License

MIT. Melvor Idle 2 is made by Games by Malcs; this is an unofficial fan project and contains
none of the game's files. The .NET runtime in the package is Microsoft's, under the MIT license.
