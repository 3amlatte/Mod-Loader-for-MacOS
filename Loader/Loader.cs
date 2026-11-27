using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Godot;

namespace MelvorModLoader;

/// <summary>Loads mod DLLs and raises their per-frame event.</summary>
public static class Loader
{
    // Mod Viewer reaches into this field to find a mod's frame handler; keep the name and shape.
    static readonly List<(ModContext Owner, Action Handler)> s_frame = new();
    static readonly List<string> s_loaded = new();
    static SceneTree s_tree = null!;

    public static string Version => Bootstrap.Version;
    public static IReadOnlyList<string> LoadedMods => s_loaded;

    internal static void Begin() => Callable.From(Start).CallDeferred();

    static void Start()
    {
        try
        {
            s_tree = (SceneTree)Engine.GetMainLoop();
            Hotkeys.Start();
            LoadMods();
            s_tree.ProcessFrame += EveryFrame;
            ShowBanner();
        }
        catch (Exception error)
        {
            Log.Write("Loader ERROR: " + error);
        }
    }

    static void LoadMods()
    {
        string modsDir = Bootstrap.ModsDir;
        if (!Directory.Exists(modsDir))
        {
            Log.Write("No mods folder: " + modsDir);
            return;
        }

        var files = new List<string>(Directory.GetFiles(modsDir, "*.dll"));
        foreach (string sub in Directory.GetDirectories(modsDir))
            files.AddRange(Directory.GetFiles(sub, "*.dll"));
        files.Sort(StringComparer.OrdinalIgnoreCase);

        foreach (string file in files)
            Bootstrap.AddProbeDir(Path.GetDirectoryName(file)!);

        foreach (string file in files)
        {
            try
            {
                Assembly assembly = Bootstrap.Alc.LoadFromAssemblyPath(file);
                foreach (Type type in assembly.GetTypes().Where(t =>
                             typeof(IMod).IsAssignableFrom(t) && !t.IsAbstract && !t.IsInterface))
                {
                    string name = assembly.GetName().Name ?? Path.GetFileNameWithoutExtension(file);
                    var mod = (IMod)Activator.CreateInstance(type)!;
                    mod.OnLoad(new ModContext(name, Path.GetDirectoryName(file)!, s_tree));
                    s_loaded.Add(name);
                    Log.Write($"Mod loaded: {name} ({Path.GetFileName(file)})");
                }
            }
            catch (Exception error)
            {
                Exception shown = error is ReflectionTypeLoadException { LoaderExceptions.Length: > 0 } many
                    ? many.LoaderExceptions[0]!
                    : error;
                Log.Write($"Mod FAILED: {Path.GetFileName(file)} -> {shown}");
            }
        }

        Log.Write($"{s_loaded.Count} mod(s) loaded");
    }

    internal static void AddFrameHandler(ModContext owner, Action handler) => s_frame.Add((owner, handler));
    internal static void RemoveFrameHandler(Action handler) => s_frame.RemoveAll(entry => entry.Handler == handler);

    static void EveryFrame()
    {
        // Offline progress runs on the game's own thread with the tree paused.
        if (s_tree.Paused) return;

        try { Hotkeys.OnFrame(s_tree); }
        catch (Exception error) { Log.Write("Hotkeys: " + error.Message); }

        for (int i = 0; i < s_frame.Count; i++)
        {
            try
            {
                s_frame[i].Handler();
            }
            catch (Exception error)
            {
                s_frame[i].Owner.Log("Frame handler stopped after an error: " + error);
                s_frame.RemoveAt(i--);
            }
        }
    }

    static void ShowBanner()
    {
        var layer = new CanvasLayer { Layer = 128, Name = "ModLoaderForMacOSBanner" };
        var blue = new Color(0.42f, 0.72f, 1f);
        var label = new Label
        {
            Text = $"{Bootstrap.ProductName} {Version}  -  {s_loaded.Count} mod{(s_loaded.Count == 1 ? "" : "s")} loaded",
            Modulate = Colors.White,
            MouseFilter = Control.MouseFilterEnum.Ignore
        };
        label.AddThemeFontSizeOverride("font_size", 14);
        label.AddThemeColorOverride("font_color", blue);
        label.AddThemeColorOverride("font_outline_color", new Color(0f, 0f, 0f, 0.85f));
        label.AddThemeConstantOverride("outline_size", 4);
        layer.AddChild(label);
        s_tree.Root.AddChild(layer);
        label.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.BottomLeft, Control.LayoutPresetMode.Minsize, 12);

        Tween fade = label.CreateTween();
        fade.TweenInterval(13.5);
        fade.TweenProperty(label, "modulate:a", 0f, 1.5);
        fade.TweenCallback(Callable.From(layer.QueueFree));
    }
}
