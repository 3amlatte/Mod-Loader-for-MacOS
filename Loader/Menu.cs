using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Godot;

namespace MelvorModLoader;

/// <summary>A key, optionally with Ctrl / Shift / Alt.</summary>
public readonly record struct KeyChord(Key Key, bool Ctrl = false, bool Shift = false, bool Alt = false)
{
    public static readonly KeyChord None = new(Key.None);
    public bool IsNone => Key == Key.None;

    public override string ToString() => IsNone
        ? string.Empty
        : (Ctrl ? "Ctrl+" : "") + (Shift ? "Shift+" : "") + (Alt ? "Alt+" : "") + OS.GetKeycodeString(Key);

    public static KeyChord Parse(string? text)
    {
        if (string.IsNullOrWhiteSpace(text) || text.Trim().Equals("None", StringComparison.OrdinalIgnoreCase))
            return None;

        bool ctrl = false, shift = false, alt = false;
        Key key = Key.None;
        foreach (string part in text.Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            switch (part.ToLowerInvariant())
            {
                case "ctrl": ctrl = true; break;
                case "shift": shift = true; break;
                case "alt": alt = true; break;
                default: key = OS.FindKeycodeFromString(part); break;
            }
        }

        return key == Key.None ? None : new KeyChord(key, ctrl, shift, alt);
    }
}

/// <summary>A mod panel that Mod Viewer can open.</summary>
public sealed class ModWindow
{
    internal ModWindow(string id, string mod, string title, Action toggle, KeyChord defaultKey)
    {
        Id = id;
        Mod = mod;
        Title = title;
        Toggle = toggle;
        DefaultKey = defaultKey;
        Key = defaultKey;
    }

    public string Id { get; }
    public string Mod { get; }
    public string Title { get; }
    public KeyChord DefaultKey { get; }
    public KeyChord Key { get; internal set; }
    public string KeyLabel => Key.ToString();

    public event Action? Changed;

    internal Action Toggle { get; }
    internal bool WasDown;

    internal void RaiseChanged()
    {
        try { Changed?.Invoke(); }
        catch (Exception error) { global::MelvorModLoader.Log.Write($"[{Mod}] key change handler: {error.Message}"); }
    }

    public void Press()
    {
        try { Toggle(); }
        catch (Exception error) { global::MelvorModLoader.Log.Write($"[{Mod}] opening '{Title}' failed: {error}"); }
    }
}

/// <summary>Registers mod panels, the F1/F2 Mod Viewer shortcut, and the top-bar Mods button.</summary>
public static class Hotkeys
{
    public const string MenuId = "MelvorModLoader:Mods";

    static readonly List<ModWindow> s_windows = new();
    static Dictionary<string, string> s_saved = new();
    static int s_frame;
    static Button? s_button;
    static CanvasLayer? s_floatingLayer;
    static bool s_inTopBar;

    public static ModWindow Menu { get; private set; } = null!;
    public static IReadOnlyList<ModWindow> Windows => s_windows;

    // Kept for binary compatibility. There is no separate panel menu any more.
    public static bool MenuVisible => false;
    public static ModWindow? Capturing => null;

    static string FilePath => Path.Combine(Bootstrap.ModsDir, "hotkeys.json");

    internal static void Start()
    {
        try
        {
            if (File.Exists(FilePath))
                s_saved = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(FilePath)) ?? new();
        }
        catch (Exception error)
        {
            Log.Write("hotkeys.json could not be read: " + error.Message);
            s_saved = new();
        }

        Menu = Add("MelvorModLoader", "Mods", ToggleModViewer, new KeyChord(Key.F1));
        EnsureButton((SceneTree)Engine.GetMainLoop());
    }

    internal static ModWindow Add(string mod, string title, Action toggle, KeyChord defaultKey)
    {
        string id = $"{mod}:{title}";
        ModWindow? old = s_windows.FirstOrDefault(window => window.Id == id);
        if (old != null) s_windows.Remove(old);

        var window = new ModWindow(id, mod, title, toggle, defaultKey);
        // F1 always opens Mod Viewer, even if an older hotkeys.json changed it.
        if (id != MenuId && s_saved.TryGetValue(id, out string? saved))
            window.Key = KeyChord.Parse(saved);
        s_windows.Add(window);

        foreach (ModWindow other in s_windows.Where(w => w != window && !w.Key.IsNone && w.Key == window.Key))
            Log.Write($"Key {window.KeyLabel} is shared by '{other.Title}' and '{window.Title}'.");

        return window;
    }

    public static void SetKey(ModWindow window, KeyChord key)
    {
        if (window.Id == MenuId) key = new KeyChord(Key.F1);
        window.Key = key;
        window.WasDown = true;
        if (key == window.DefaultKey) s_saved.Remove(window.Id);
        else s_saved[window.Id] = key.IsNone ? "None" : key.ToString();
        Save();
        window.RaiseChanged();
    }

    public static void ResetAll()
    {
        foreach (ModWindow window in s_windows.Where(w => w.Key != w.DefaultKey).ToList())
        {
            window.Key = window.DefaultKey;
            window.RaiseChanged();
        }

        s_saved.Clear();
        Save();
    }

    public static IEnumerable<ModWindow> SharingKey(ModWindow window) =>
        window.Key.IsNone ? Enumerable.Empty<ModWindow>() : s_windows.Where(w => w != window && w.Key == window.Key);

    // Kept for binary compatibility with older mods. Keys are edited by Mod Viewer now.
    public static void BeginCapture(ModWindow window) { }
    public static void CancelCapture() { }

    static void Save()
    {
        try
        {
            File.WriteAllText(FilePath, JsonSerializer.Serialize(s_saved,
                new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception error)
        {
            Log.Write("hotkeys.json could not be saved: " + error.Message);
        }
    }

    static ModWindow? ViewerWindow() => s_windows.FirstOrDefault(window =>
        window.Title.Equals("Mod Viewer", StringComparison.OrdinalIgnoreCase) &&
        window.Mod.Equals("ModViewer", StringComparison.OrdinalIgnoreCase));

    static void ToggleModViewer()
    {
        ModWindow? viewer = ViewerWindow();
        if (viewer != null)
        {
            viewer.Press();
            return;
        }

        const string message = "Mod Viewer is missing or did not load. Reinstall Mod Loader for MacOS.";
        Log.Write("Loader ERROR: " + message);
        Loader.ShowError(message);
    }

    // Kept for API compatibility. F1 and the Mods button now open Mod Viewer.
    public static void ToggleMenu() => ToggleModViewer();

    internal static void OnFrame(SceneTree tree)
    {
        if (++s_frame % 60 == 0) EnsureButton(tree);

        bool typing = tree.Root.GuiGetFocusOwner() is LineEdit or TextEdit;
        bool ctrl = Input.IsKeyPressed(Key.Ctrl);
        bool shift = Input.IsKeyPressed(Key.Shift);
        bool alt = Input.IsKeyPressed(Key.Alt);

        foreach (ModWindow window in s_windows.ToList())
        {
            if (window.Key.IsNone)
            {
                window.WasDown = false;
                continue;
            }

            // F1 is reserved for Mod Viewer; other mods may still use modified F1 chords.
            if (window.Id != MenuId && window.Key.Key == Key.F1 && !window.Key.Ctrl && !window.Key.Shift && !window.Key.Alt)
            {
                window.WasDown = false;
                continue;
            }

            bool down = Input.IsKeyPressed(window.Key.Key)
                        && window.Key.Ctrl == ctrl
                        && window.Key.Shift == shift
                        && window.Key.Alt == alt;
            bool pressed = down && !window.WasDown;
            window.WasDown = down;
            if (!pressed) continue;
            if (typing && !IsFunctionKey(window.Key.Key) && !window.Key.Ctrl && !window.Key.Alt) continue;
            window.Press();
        }
    }

    static bool IsFunctionKey(Key key) => key >= Key.F1 && key <= Key.F35;

    static void EnsureButton(SceneTree tree)
    {
        try
        {
            if (s_button != null && GodotObject.IsInstanceValid(s_button) && s_button.IsInsideTree())
            {
                if (!s_inTopBar && TryPlaceInTopBar(tree)) RemoveFloating();
                UpdateButton();
                return;
            }

            s_button = null;
            if (!TryPlaceInTopBar(tree)) CreateFloatingButton(tree);
            UpdateButton();
        }
        catch (Exception error)
        {
            Log.Write("Mods button could not be created: " + error.Message);
        }
    }

    static bool TryPlaceInTopBar(SceneTree tree)
    {
        Control? anchor = tree.Root.FindChild("GuideNavigationButton", true, false) as Control
                          ?? tree.Root.FindChild("BankNavigationButton", true, false) as Control;
        if (anchor?.GetParent() is not BoxContainer row) return false;

        if (row.FindChild("ModLoaderForMacOSModsButton", false, false) is Button old)
        {
            row.RemoveChild(old);
            old.QueueFree();
        }

        Button button = MakeButton("ModLoaderForMacOSModsButton");
        button.CustomMinimumSize = new Vector2(56, 34);
        row.AddChild(button);
        row.MoveChild(button, anchor.GetIndex() + 1);
        s_button = button;
        s_inTopBar = true;
        return true;
    }

    static void CreateFloatingButton(SceneTree tree)
    {
        RemoveFloating();
        var layer = new CanvasLayer { Layer = 127, Name = "ModLoaderForMacOSButton" };
        var root = new Control { MouseFilter = Control.MouseFilterEnum.Ignore };
        root.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        layer.AddChild(root);

        Button button = MakeButton("ModLoaderForMacOSModsButton");
        button.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.TopRight);
        button.OffsetLeft = -82;
        button.OffsetTop = 8;
        button.OffsetRight = -12;
        button.OffsetBottom = 38;
        root.AddChild(button);

        tree.Root.AddChild(layer);
        s_floatingLayer = layer;
        s_button = button;
        s_inTopBar = false;
    }

    static Button MakeButton(string name)
    {
        var button = new Button
        {
            Name = name,
            Text = "Mods",
            Flat = true,
            FocusMode = Control.FocusModeEnum.None,
            MouseDefaultCursorShape = Control.CursorShape.PointingHand,
            CustomMinimumSize = new Vector2(64, 28)
        };

        var hover = new StyleBoxFlat { BgColor = new Color(1f, 1f, 1f, 0.07f) };
        hover.SetCornerRadiusAll(5);
        button.AddThemeColorOverride("font_color", new Color(0.89f, 0.76f, 0.52f));
        button.AddThemeColorOverride("font_hover_color", new Color(1f, 0.95f, 0.85f));
        button.AddThemeStyleboxOverride("normal", new StyleBoxEmpty());
        button.AddThemeStyleboxOverride("focus", new StyleBoxEmpty());
        button.AddThemeStyleboxOverride("hover", hover);
        button.AddThemeStyleboxOverride("pressed", hover);
        button.Pressed += ToggleModViewer;
        return button;
    }

    static void RemoveFloating()
    {
        if (s_floatingLayer != null && GodotObject.IsInstanceValid(s_floatingLayer))
            s_floatingLayer.QueueFree();
        s_floatingLayer = null;
    }

    static void UpdateButton()
    {
        if (s_button == null) return;
        ModWindow? viewer = ViewerWindow();
        string key = Menu.KeyLabel;
        if (viewer != null && viewer.KeyLabel.Length > 0 && viewer.KeyLabel != key)
            key += " / " + viewer.KeyLabel;
        s_button.TooltipText = "Mod Viewer" + (key.Length == 0 ? "" : $"  ({key})")
                               + (viewer == null
                                   ? "\nMod Viewer did not load. Reinstall the loader."
                                   : "\nOpen Mod Viewer.");
        s_button.Modulate = viewer == null ? new Color(1f, 0.55f, 0.55f) : Colors.White;
    }
}
