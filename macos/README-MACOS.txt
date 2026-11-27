Mod Loader for MacOS 1.0.3 for macOS (experimental)
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


Install (Terminal, recommended)
-------------------------------
There is no installer .app in this package. Opening an unsigned app is exactly
the Gatekeeper prompt this avoids. install.sh is readable text; open it first if
you want to see every change it makes.

1. Quit Melvor Idle 2.
2. Unzip this package (double-click the zip).
3. Open Terminal.
4. Change to the unzipped folder, for example:
       cd ~/Downloads/ModLoaderForMacOS-1.0.3-macos
5. Run:
       bash install.sh
6. Start Melvor Idle 2 from Steam. The blue loader status line shows at the
   bottom-left for 15 seconds.

The script finds the game in the usual Steam folder; if it cannot, it stops and
tells you to pass the path:

       bash install.sh "/path/to/Melvor Idle 2.app"

It copies the loader into Contents/Resources, writes Contents/MacOS/override.cfg,
creates the mods folder, installs Mod Viewer only when no Mod Viewer is present,
and re-signs the bundle ad-hoc. An earlier Mod Viewer from this project is
updated; a third-party Mod Viewer is left alone.

The script's log is:
    ~/Library/Application Support/MelvorModLoader/install.log


Manual copy (advanced, no script)
---------------------------------
Use this only if you do not want to run install.sh. It does the same copy, but
you must re-sign the bundle yourself or macOS may refuse to start it.

1. Quit Melvor Idle 2.
2. Right-click Melvor Idle 2.app and choose "Show Package Contents".
3. Copy the loader folder for your Mac from this package into Contents/Resources:
       data_MelvorModLoader_macos_arm64    (Apple Silicon)
       data_MelvorModLoader_macos_x86_64   (Intel)
   Copy either one, or both if you are not sure.
4. Copy override.cfg from this package into Contents/MacOS.
5. Copy this package's ModViewer folder (inside mods/) into:
       ~/Library/Application Support/MelvorModLoader/mods/
   Do this only if you do not already have a Mod Viewer. If you have an older
   copy from this project, replace that folder; leave a third-party one alone.
6. Re-sign the bundle:
       codesign --force --deep --sign - "/path/to/Melvor Idle 2.app"
7. Start the game from Steam.

After a manual copy the structure is:

    Melvor Idle 2.app/Contents/MacOS/override.cfg
    Melvor Idle 2.app/Contents/Resources/data_MelvorModLoader_macos_*/


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
each loader folder. The game's own binary and data are untouched.

Adding files invalidates the .app signature, so install.sh re-signs the bundle
ad-hoc. That recomputes the signature and lets the bundled .NET runtime load.
(Set MELVOR_SKIP_SIGN=1 to skip re-signing when running install.sh.)


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

Mod Viewer 0.1.11 is included in this package. install.sh adds it only when
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

It is rewritten on every start. The install script's own log is install.log in
the same folder. If Application Support is not writable, the loader falls back
to the game folder and then /tmp.


Uninstall
---------
In Terminal, from the unzipped package:

    bash uninstall.sh

Or pass the game path:

    bash uninstall.sh "/path/to/Melvor Idle 2.app"

Or manually, inside the app bundle, delete:
    Contents/MacOS/override.cfg
    Contents/Resources/data_MelvorModLoader_macos_arm64
    Contents/Resources/data_MelvorModLoader_macos_x86_64

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
- There is no installer app and nothing is notarized by Apple. You run a readable
  shell script instead of opening an unsigned .app.
