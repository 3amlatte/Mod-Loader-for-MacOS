using System;
using System.Runtime.InteropServices;

namespace GodotPlugins.Game;

// Godot calls this exported symbol instead of the game's own entry point because
// override.cfg points dotnet/project/assembly_name at this assembly.
internal static class Main
{
    [UnmanagedCallersOnly(EntryPoint = "godotsharp_game_main_init")]
    private static byte InitializeFromGameProject(nint godotDllHandle, nint outManagedCallbacks,
        nint unmanagedCallbacks, int unmanagedCallbacksSize)
    {
        try
        {
            MelvorModLoader.Bootstrap.Run(godotDllHandle, outManagedCallbacks, unmanagedCallbacks, unmanagedCallbacksSize);
            return 1;
        }
        catch (Exception error)
        {
            MelvorModLoader.Log.Write("STARTUP ERROR: " + error);
            return 0;
        }
    }
}
