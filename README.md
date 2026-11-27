# Mod Loader for MacOS

An independent C# mod loader for **Melvor Idle 2** (Steam), packaged for macOS on Apple Silicon and Intel.

> **macOS only.** This loader does not support Windows. For Windows, use
> [Melvor Mod Loader by falorfrozen](https://github.com/falorfrozen-cmd/MelvorModLoader).

It implements the same public mod API as Melvor Mod Loader (`IMod`, `ModContext`, `GameAccess`,
`ModWindow`, `Hotkeys`) so existing mod DLLs load without being rebuilt. The implementation is
new; it is **not** the original Melvor Mod Loader.

## What it does

- Loads every DLL under `mods` (flat or one folder deep).
- A broken mod is logged and skipped; the game and other mods keep running.
- Raises `ModContext.Frame` once per rendered frame, and pauses it while the game computes
  offline progress.
- Shows a blue status line at the bottom-left for 15 seconds with the loader version and mod
  count, then fades it out.
- The top-bar **Mods** button or **F1** opens **Mod Viewer** (F2 also works). Mod Viewer is part
  of the loader, so it cannot be disabled. If it is missing, the loader reports an error and
  needs to be reinstalled.
- Uses Godot's own `override.cfg` mechanism: the loader starts first, then starts the game's
  untouched managed code. No game file is modified or replaced.
- On macOS, mods, settings, and logs live in `~/Library/Application Support/MelvorModLoader`,
  outside the signed `.app`, so game updates do not delete them.

## Install (macOS)

No installer `.app` is included. The package uses a readable `.command` script instead:

1. Quit Melvor Idle 2.
2. Unzip the package.
3. Double-click **Install Mod Loader for MacOS.command**.
4. Start Melvor Idle 2 from Steam.

If macOS blocks the `.command`, right-click it -> **Open**, or run `bash install.sh` from
Terminal in the unzipped folder.

The script finds the game, copies the loader into `Melvor Idle 2.app`, installs the required
Mod Viewer, and re-signs the bundle ad-hoc. You can read the `.command` and `install.sh` before
running them. If the game is somewhere else:

```bash
bash install.sh "/path/to/Melvor Idle 2.app"
```

## Compatibility

The assembly is named `MelvorModLoader` and the public types live in the `MelvorModLoader`
namespace because that is the binary contract existing mods reference. The product name and
implementation are Mod Loader for MacOS. Existing mods load unchanged; mods do not get the original
loader's code.

## License

MIT. See [LICENSE](LICENSE). Melvor Idle 2 is made by Games by Malcs; this is an unofficial fan
project and contains none of the game's files. The .NET runtime included in the package is
Microsoft's, under the MIT license.
