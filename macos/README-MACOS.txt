Mod Loader for MacOS 1.0.1 for macOS (experimental)
=================================================

This is Mod Loader for MacOS, an independent loader for Melvor Idle 2. It keeps the public
mod API names so existing mods load, but it is not the original loader. It has
not been tested on a Mac by the author of this build. Treat it as experimental:
back up saves you care about, and know how to Uninstall (bottom of this file).


Requirements
------------
- macOS 14 or newer (the .NET 10 minimum; if the game runs, yours is new enough),
  Apple Silicon or Intel.
- Melvor Idle 2 from Steam, the native macOS build.
- The C# (Godot .NET) build of the game. The loader looks for
  Contents/Resources/data_GamesByMalcs.Melvor2_macos_* inside the app.


Windows
-------
This package is macOS-only. For Windows, use Melvor Mod Loader by falorfrozen:
https://github.com/falorfrozen-cmd/MelvorModLoader


Easy install (double-click)
---------------------------
1. Quit Melvor Idle 2.
2. Unzip this package (double-click the zip).
3. Double-click:   Install Mod Loader for MacOS.app
4. If macOS says it cannot verify the app, right-click it, choose Open, then
   Open again. (Or: System Settings > Privacy & Security > Open Anyway.)
   This is only because the installer is not signed by a paid Apple Developer
   account. It changes nothing else.
5. Click Install. It finds the game in the usual Steam folder; if it cannot, it
   asks you to pick Melvor Idle 2.app. It installs the loader, and Mod Viewer if
   no Mod Viewer is already installed. An earlier copy from this project is
   updated; a third-party Mod Viewer is left alone.
6. When it finishes, click Start Game (or start the game from Steam).

Keep the app inside the unzipped folder: it uses install.sh and the loader
folders next to it. If something fails, click Show Log; the log is also at
    ~/Library/Application Support/MelvorModLoader/install.log


Manual install (drag and drop, no app)
--------------------------------------
On macOS the game is an .app bundle, so "the game folder" is inside it and there are two destinations:

1. Right-click Melvor Idle 2.app and choose "Show Package Contents".
2. Copy the loader folder for your Mac from this package into Contents/Resources:
       data_MelvorModLoader_macos_arm64    (Apple Silicon)
       data_MelvorModLoader_macos_x86_64   (Intel)
   Copy either one, or both if you are not sure.
3. Copy override.cfg from this package into Contents/MacOS.
4. Copy this package's ModViewer folder (inside mods/) into:
       ~/Library/Application Support/MelvorModLoader/mods/
   Do this only if you do not already have a Mod Viewer. If you have an older
   copy from this project, replace that folder; leave a third-party one alone.
5. Start the game from Steam. The green loader line shows for 15 seconds.

The result is the same files the installer app puts there. The only difference
is the app signature: adding files invalidates it. Most Steam-installed copies
still start, and the loader usually loads. If the green line does not appear
(or the game refuses to start), run Install Mod Loader for MacOS.app once; it
re-copies the loader and re-signs the bundle. That is the reliable path.

After a manual copy the structure is:

    Melvor Idle 2.app/Contents/MacOS/override.cfg
    Melvor Idle 2.app/Contents/Resources/data_MelvorModLoader_macos_*/


Terminal (advanced)
-------------------
    bash install.sh
    bash install.sh "/Applications/Melvor Idle 2.app"


What the loader adds
--------------------
Inside Melvor Idle 2.app:

    Contents/MacOS/override.cfg                            new
    Contents/Resources/data_MelvorModLoader_macos_arm64    new (Apple Silicon)
    Contents/Resources/data_MelvorModLoader_macos_x86_64   new (Intel)

And in the mods folder:

    ~/Library/Application Support/MelvorModLoader/mods/ModViewer    new (0.1.11,
                                                                    unless you
                                                                    already have
                                                                    a Mod Viewer)

No game file is modified or replaced. A copy of the .NET 10 runtime goes into
each loader folder. The app bundle itself gets
the new files, and the installer app gives it a new ad-hoc signature; that is the
macOS equivalent of adding files next to the game executable.

The installer app additionally re-signs the bundle ad-hoc. macOS signs the whole
.app, so any addition invalidates Apple's signature; re-signing recomputes it and
lets the bundled .NET runtime load. The game's own binary and data are untouched.
(Set MELVOR_SKIP_SIGN=1 to skip re-signing in the Terminal script.)


Mods
----
The mods folder lives outside the app, so game updates do not delete mods or
their settings:

    ~/Library/Application Support/MelvorModLoader/mods

Mod zips contain a top-level "mods" folder. Extract them into

    ~/Library/Application Support/MelvorModLoader

and the mod lands in .../MelvorModLoader/mods/<ModName>/.

The loader creates that folder on first start and always uses it on macOS.
MELVOR_MODLOADER_MODS=/some/folder overrides the choice for one launch.

Mod Viewer 0.1.11 is included in this package. The installer adds it only when
no Mod Viewer is already in the mods folder. An earlier copy from this project
(its folder has a 3am.mod marker) is updated in place. A Mod Viewer from someone
else is left untouched, and nothing in mods-disabled is deleted. Your Mod Viewer
settings and groups are kept. To switch from another Mod Viewer to the bundled
one, delete the other folder yourself first.

Mod Viewer 0.1.11 opens the mods folder with the macOS "open" command and
restarts Steam with /bin/sh instead of PowerShell.

Most other mods are net10.0 class libraries and are platform-neutral. F1-F9 may
require holding Fn on Apple keyboards; the Mods button in the game's top bar
always works.


Log
---
    ~/Library/Application Support/MelvorModLoader/ModLoaderForMacOS.log

It is rewritten on every start. The installer's own log is install.log in the
same folder. If Application Support is not writable, the loader falls back to
the game folder and then /tmp.


Uninstall
---------
Double-click:   Uninstall Mod Loader for MacOS.app

Or manually, inside the app bundle, delete:
    Contents/MacOS/override.cfg
    Contents/Resources/data_MelvorModLoader_macos_arm64
    Contents/Resources/data_MelvorModLoader_macos_x86_64

Or in Terminal:

    bash Uninstall.sh

Mods and settings (including the installed ModViewer) stay in Application
Support; delete that folder yourself to remove them.

If the game ever fails to start, deleting Contents/MacOS/override.cfg is enough
to run it unmodded.


Known limits
------------
- Experimental and not tested on a Mac.
- Steam updates replace the .app and remove the loader; install it again.
- The game is in Early Access; a game update can break the loader or a mod until
  they are updated.
- The loader writes nothing into your save files. A cheat mod changes your
  character the same way playing would, and those changes stay if you remove it.
- The installer app is not notarized by Apple; the manual copy avoids the app but
  leaves the bundle signature invalid. Use the app if the manual copy does not
  load.
