Mod Loader for MacOS 1.0.8 for macOS (manual install)
=====================================================

This is the Nexus package. It contains no installer scripts or .app bundles.
The GitHub release has the one-click installer if you prefer it:
https://github.com/3amlatte/Mod-Loader-for-MacOS/releases/tag/v1.0.8


REQUIREMENTS
------------
- macOS 14 or newer, Apple Silicon or Intel.
- Melvor Idle 2 from Steam, the native macOS C# build.


INSTALL
-------
1. Quit Melvor Idle 2.
2. Right-click Melvor Idle 2.app and choose "Show Package Contents".
3. Copy the loader folder for your Mac into Contents/Resources:
       data_MelvorModLoader_macos_arm64    (Apple Silicon)
       data_MelvorModLoader_macos_x86_64   (Intel)
   Copy either one, or both if you are not sure.
4. Copy override.cfg into Contents/MacOS.
5. Copy both folders from this package's mods folder into:
       ~/Library/Application Support/MelvorModLoader/mods/
   The folders are ModViewer and BackupSaver. Create the mods folder if needed.
6. Re-sign the game bundle:
       codesign --force --deep --sign - "/path/to/Melvor Idle 2.app"

   Example Steam path:
       codesign --force --deep --sign - "$HOME/Library/Application Support/Steam/steamapps/common/Melvor Idle 2/Melvor Idle 2.app"

7. Start Melvor Idle 2 from Steam.

The Mods button, F1, or F2 opens Mod Viewer. Mod Viewer is required and cannot
be disabled. Backup Saver keeps the five newest save backups in:

    ~/Library/Application Support/MelvorModLoader/backups/


RESTORE A BACKUP
----------------
1. Quit Melvor Idle 2.
2. Open the dated backup folder you want.
3. Copy its saves folder over the game's saves folder, keeping the same paths.

The game's user-data folder is usually:

    ~/Library/Application Support/Games By Malcs/Melvor Idle 2/

For Steam it is:

    .../Games By Malcs/Melvor Idle 2/steam/<steam-id>/saves/


UNINSTALL
---------
Quit the game, then delete from the app bundle:
    Contents/MacOS/override.cfg
    Contents/Resources/data_MelvorModLoader_macos_arm64
    Contents/Resources/data_MelvorModLoader_macos_x86_64

Then re-sign:
    codesign --force --deep --sign - "/path/to/Melvor Idle 2.app"

Mods and settings stay in ~/Library/Application Support/MelvorModLoader.


NOTES
-----
- No game file is modified or replaced.
- Steam updates replace the app; install the loader again afterwards.
- This build is experimental and has not been tested on a physical Mac.
- Windows is not supported. For Windows, use Melvor Mod Loader by falorfrozen:
  https://github.com/falorfrozen-cmd/MelvorModLoader
