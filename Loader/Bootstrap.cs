using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Loader;

namespace MelvorModLoader;

/// <summary>Starts Godot's managed game code, then the loader.</summary>
internal static class Bootstrap
{
    const string GameAssembly = "GamesByMalcs.Melvor2";

    public const string ProductName = "Mod Loader for MacOS";

    public static string LoaderDir = string.Empty;
    public static string GameRoot = string.Empty;
    public static string GameDataDir = string.Empty;
    public static string ModsDir = string.Empty;
    public static AssemblyLoadContext Alc = null!;

    static readonly List<string> ProbeDirs = new();

    public static string Version =>
        typeof(Bootstrap).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "1.0.0";

    /// <summary>~/Library/Application Support/MelvorModLoader on macOS. Kept for mod compatibility.</summary>
    public static string SupportDir()
    {
        string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (home.Length == 0) home = Environment.GetEnvironmentVariable("HOME") ?? string.Empty;
        return Path.Combine(home, "Library", "Application Support", "MelvorModLoader");
    }

    public static void Run(nint godotDllHandle, nint outManagedCallbacks, nint unmanagedCallbacks, int unmanagedCallbacksSize)
    {
        Assembly self = typeof(Bootstrap).Assembly;
        LoaderDir = Path.GetDirectoryName(Path.GetFullPath(self.Location))!;
        GameRoot = Path.GetDirectoryName(LoaderDir)!;
        ModsDir = PickModsDir();
        Log.StartNewSession(GameRoot);
        Log.Write($"{ProductName} {Version} starting (.NET {Environment.Version})");

        GameDataDir = LocateGameData();
        Log.Write("Game data folder: " + GameDataDir);

        Alc = AssemblyLoadContext.GetLoadContext(self)!;
        ProbeDirs.Add(GameDataDir);
        Alc.Resolving += Resolve;

        StartGodot(godotDllHandle, outManagedCallbacks, unmanagedCallbacks, unmanagedCallbacksSize);
        Log.Write("Game started");
        Loader.Begin();
    }

    // The same four calls Godot makes for a C# game, with the game's assembly registered
    // as the one holding its scripts. Kept out of line so game types resolve lazily.
    [MethodImpl(MethodImplOptions.NoInlining)]
    static void StartGodot(nint godotDllHandle, nint outManagedCallbacks, nint unmanagedCallbacks, int unmanagedCallbacksSize)
    {
        DllImportResolver resolver = new Godot.NativeInterop.GodotDllImportResolver(godotDllHandle).OnResolveDllImport;
        NativeLibrary.SetDllImportResolver(typeof(Godot.GodotObject).Assembly, resolver);
        Godot.NativeInterop.NativeFuncs.Initialize(unmanagedCallbacks, unmanagedCallbacksSize);
        Godot.Bridge.ManagedCallbacks.Create(outManagedCallbacks);
        Godot.Bridge.ScriptManagerBridge.LookupScriptsInAssembly(typeof(GamesByMalcs.Melvor2.Game).Assembly);
    }

    static string PickModsDir()
    {
        string? custom = Environment.GetEnvironmentVariable("MACOS_MODLOADER_MODS")
                         ?? Environment.GetEnvironmentVariable("MELVOR_MODLOADER_MODS");
        if (!string.IsNullOrWhiteSpace(custom))
        {
            try { return Path.GetFullPath(custom!); } catch { return custom!; }
        }

        if (OperatingSystem.IsMacOS())
        {
            string mods = Path.Combine(SupportDir(), "mods");
            try { Directory.CreateDirectory(mods); } catch { }
            if (Directory.Exists(mods)) return mods;
        }

        return Path.Combine(GameRoot, "mods");
    }

    static string LocateGameData()
    {
        var roots = new List<string> { GameRoot };
        string parent = Path.GetDirectoryName(GameRoot) ?? string.Empty;
        if (parent.Length > 0)
        {
            roots.Add(Path.Combine(parent, "Resources"));
            roots.Add(Path.Combine(parent, "MacOS"));
        }

        foreach (string root in roots)
        {
            if (!Directory.Exists(root)) continue;

            string windowsName = Path.Combine(root, "data_" + GameAssembly + "_windows_x86_64");
            if (File.Exists(Path.Combine(windowsName, GameAssembly + ".dll"))) return windowsName;

            foreach (string candidate in Directory.GetDirectories(root, "data_*"))
                if (File.Exists(Path.Combine(candidate, GameAssembly + ".dll")))
                    return candidate;
        }

        throw new DirectoryNotFoundException(
            $"The game's data folder was not found ({GameAssembly}.dll). Install the loader into the game folder.");
    }

    public static void AddProbeDir(string directory)
    {
        if (!ProbeDirs.Contains(directory)) ProbeDirs.Add(directory);
    }

    static Assembly? Resolve(AssemblyLoadContext context, AssemblyName name)
    {
        foreach (string directory in ProbeDirs)
        {
            string path = Path.Combine(directory, name.Name + ".dll");
            if (File.Exists(path)) return context.LoadFromAssemblyPath(path);
        }

        return null;
    }
}
