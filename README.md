# Mod Loader for MacOS

An independent C# mod loader for **Melvor Idle 2** (Steam), packaged for macOS on Apple Silicon and Intel.

It implements the same public mod API as Melvor Mod Loader (`IMod`, `ModContext`, `GameAccess`,
`ModWindow`, `Hotkeys`) so existing mod DLLs load without being rebuilt. The implementation is
new; it is **not** the original Melvor Mod Loader.

## What it does

- Loads every DLL under `mods` (flat or one folder deep).
- A broken mod is logged and skipped; the game and other mods keep running.
- Raises `ModContext.Frame` once per rendered frame, and pauses it while the game computes
  offline progress.
- Shows a green line at the top-left for 15 seconds with the loader version and mod count.
- Adds a **Mods** menu (top bar button, or F1) that lists every registered mod window and lets
  players change or switch off its key. Choices are stored in `mods/hotkeys.json`.
- Uses Godot's own `override.cfg` mechanism: the loader starts first, then starts the game's
  untouched managed code. No game file is modified or replaced.
- On macOS, mods, settings, and logs live in `~/Library/Application Support/MelvorModLoader`,
  outside the signed `.app`, so game updates do not delete them.

## Install (macOS)

1. Quit Melvor Idle 2.
2. Unzip the package.
3. Double-click **Install Mod Loader for MacOS.app** and click **Install**.
4. If macOS cannot verify the app, right-click it -> Open -> Open (or System Settings ->
   Privacy & Security -> Open Anyway).

The installer adds the loader inside `Melvor Idle 2.app` and re-signs the bundle ad-hoc. Manual
and Terminal instructions are in `macos/README-MACOS.txt`.

## Build

Requires the .NET 10 SDK and the game's managed DLLs.

```powershell
dotnet publish Loader/MelvorModLoader.csproj -c Release -r osx-arm64 `n  -p:GameData=".../data_GamesByMalcs.Melvor2_macos_arm64" -p:UseAppHost=false
```

macOS package:

```powershell
pwsh ./macos/build-macos.ps1 `
  -GameData ".../data_GamesByMalcs.Melvor2_macos_arm64" `
  -ModViewerZip ".../ModViewer-0.1.11.zip"
```

The build script publishes `osx-arm64` and `osx-x64`, adds the app bundle, installer, Mod Viewer,
and logo assets.

## Compatibility

The assembly is named `MelvorModLoader` and the public types live in the `MelvorModLoader`
namespace because that is the binary contract existing mods reference. The product name and
implementation are Mod Loader for MacOS. Existing mods load unchanged; mods do not get the original
loader's code.

## License

MIT. See [LICENSE](LICENSE). Melvor Idle 2 is made by Games by Malcs; this is an unofficial fan
project and contains none of the game's files. The .NET runtime included in the package is
Microsoft's, under the MIT license.