using System;
using System.Runtime.CompilerServices;
using GamesByMalcs.Melvor2.GameMenus;
using Godot;

namespace MelvorModLoader;

/// <summary>A mod's entry class.</summary>
public interface IMod
{
    void OnLoad(ModContext context);
}

/// <summary>What the loader gives a mod.</summary>
public sealed class ModContext
{
    public string Name { get; }
    public string Directory { get; }
    public SceneTree Tree { get; }

    internal ModContext(string name, string directory, SceneTree tree)
    {
        Name = name;
        Directory = directory;
        Tree = tree;
    }

    public void Log(string message) => global::MelvorModLoader.Log.Write($"[{Name}] {message}");

    /// <summary>Adds a window to the loader's Mods menu and gives it an optional key.</summary>
    public ModWindow AddWindow(string title, Action toggle, Key defaultKey = Key.None) =>
        Hotkeys.Add(Name, title, toggle, new KeyChord(defaultKey));

    /// <summary>Called once per rendered frame, except while offline progress is computed.</summary>
    public event Action Frame
    {
        add => Loader.AddFrameHandler(this, value);
        remove => Loader.RemoveFrameHandler(value);
    }
}

/// <summary>Convenience access to the running game.</summary>
public static class GameAccess
{
    public static T? FindNode<T>(Node? root = null) where T : Node
    {
        root ??= ((SceneTree)Engine.GetMainLoop()).Root;
        if (root is T direct) return direct;

        foreach (Node child in root.GetChildren(includeInternal: true))
        {
            T? found = FindNode<T>(child);
            if (found != null) return found;
        }

        return null;
    }

    public static bool IsComputingOffline => ((SceneTree)Engine.GetMainLoop()).Paused;

    public static GameView? FindGameView() => FindNode<GameView>();

    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_Game")]
    static extern GamesByMalcs.Melvor2.Game? GetGame(GameView view);

    public static GamesByMalcs.Melvor2.Game? CurrentGame
    {
        get
        {
            GameView? view = FindGameView();
            return view == null ? null : GetGame(view);
        }
    }
}
