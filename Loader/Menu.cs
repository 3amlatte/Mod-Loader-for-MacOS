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

/// <summary>A mod window listed in the Mods menu.</summary>
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

/// <summary>Shared keys and the Mods menu.</summary>
public static class Hotkeys
{
    public const string MenuId = "MelvorModLoader:Mods";

    static readonly List<ModWindow> s_windows = new();
    static Dictionary<string, string> s_saved = new();
    static MenuView? s_menu;
    static ModWindow? s_capturing;
    static Key s_ignore = Key.None;
    static bool s_escapeWasDown;
    static int s_frame;
    static Button? s_button;
    static CanvasLayer? s_floatingLayer;
    static bool s_inTopBar;

    public static ModWindow Menu { get; private set; } = null!;
    public static IReadOnlyList<ModWindow> Windows => s_windows;
    public static bool MenuVisible => s_menu is { Visible: true };
    public static ModWindow? Capturing => s_capturing;

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

        Menu = Add("MelvorModLoader", "Mods", ToggleMenu, new KeyChord(Key.F1));
        EnsureButton((SceneTree)Engine.GetMainLoop());
    }

    internal static ModWindow Add(string mod, string title, Action toggle, KeyChord defaultKey)
    {
        string id = $"{mod}:{title}";
        ModWindow? old = s_windows.FirstOrDefault(window => window.Id == id);
        if (old != null) s_windows.Remove(old);

        var window = new ModWindow(id, mod, title, toggle, defaultKey);
        if (s_saved.TryGetValue(id, out string? saved)) window.Key = KeyChord.Parse(saved);
        s_windows.Add(window);

        foreach (ModWindow other in s_windows.Where(w => w != window && !w.Key.IsNone && w.Key == window.Key))
            Log.Write($"Key {window.KeyLabel} is shared by '{other.Title}' and '{window.Title}'.");

        s_menu?.Rebuild();
        return window;
    }

    public static void SetKey(ModWindow window, KeyChord key)
    {
        window.Key = key;
        window.WasDown = true;
        if (key == window.DefaultKey) s_saved.Remove(window.Id);
        else s_saved[window.Id] = key.IsNone ? "None" : key.ToString();
        Save();
        window.RaiseChanged();
        s_menu?.Rebuild();
    }

    public static void ResetAll()
    {
        s_capturing = null;
        foreach (ModWindow window in s_windows.Where(w => w.Key != w.DefaultKey).ToList())
        {
            window.Key = window.DefaultKey;
            window.RaiseChanged();
        }

        s_saved.Clear();
        Save();
        s_menu?.Rebuild();
    }

    public static IEnumerable<ModWindow> SharingKey(ModWindow window) =>
        window.Key.IsNone ? Enumerable.Empty<ModWindow>() : s_windows.Where(w => w != window && w.Key == window.Key);

    public static void BeginCapture(ModWindow window)
    {
        s_capturing = window;
        s_menu?.Rebuild();
    }

    public static void CancelCapture()
    {
        s_capturing = null;
        s_ignore = Key.Escape;
        s_menu?.Rebuild();
    }

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

    public static void ToggleMenu()
    {
        if (s_menu is { Visible: true })
        {
            s_menu.Close();
            return;
        }

        s_menu ??= new MenuView();
        s_menu.Open();
    }

    internal static void OnFrame(SceneTree tree)
    {
        if (++s_frame % 60 == 0) EnsureButton(tree);
        if (s_capturing != null) { Capture(); return; }

        if (s_ignore != Key.None)
        {
            if (Input.IsKeyPressed(s_ignore)) return;
            s_ignore = Key.None;
        }

        bool escape = Input.IsKeyPressed(Key.Escape);
        if (escape && !s_escapeWasDown && s_menu is { Visible: true }) s_menu.Close();
        s_escapeWasDown = escape;

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

    static readonly Key[] s_choosable = BuildChoosable();

    static Key[] BuildChoosable()
    {
        var keys = new List<Key>();
        for (Key key = Key.F1; key <= Key.F12; key++) keys.Add(key);
        for (Key key = Key.A; key <= Key.Z; key++) keys.Add(key);
        for (Key key = Key.Key0; key <= Key.Key9; key++) keys.Add(key);
        for (Key key = Key.Kp0; key <= Key.Kp9; key++) keys.Add(key);
        keys.AddRange(new[]
        {
            Key.Insert, Key.Delete, Key.Home, Key.End, Key.Pageup, Key.Pagedown, Key.Pause, Key.Scrolllock,
            Key.Quoteleft, Key.Minus, Key.Equal, Key.Bracketleft, Key.Bracketright, Key.Backslash, Key.Semicolon,
            Key.Apostrophe, Key.Comma, Key.Period, Key.Slash, Key.KpAdd, Key.KpSubtract, Key.KpMultiply, Key.KpDivide
        });
        return keys.ToArray();
    }

    static void Capture()
    {
        if (s_ignore != Key.None)
        {
            if (Input.IsKeyPressed(s_ignore)) return;
            s_ignore = Key.None;
        }

        if (Input.IsKeyPressed(Key.Escape))
        {
            CancelCapture();
            return;
        }

        foreach (Key key in s_choosable)
        {
            if (!Input.IsKeyPressed(key)) continue;
            ModWindow window = s_capturing!;
            s_capturing = null;
            s_ignore = key;
            SetKey(window, new KeyChord(key,
                Input.IsKeyPressed(Key.Ctrl),
                Input.IsKeyPressed(Key.Shift),
                Input.IsKeyPressed(Key.Alt)));
            return;
        }
    }

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
        button.Pressed += ToggleMenu;
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
        string key = Menu.KeyLabel;
        bool clash = s_windows.Any(window => SharingKey(window).Any());
        s_button.TooltipText = "Mods" + (key.Length == 0 ? "" : $"  ({key})")
                               + "\nOpen any mod window, or change or switch off its key."
                               + (clash ? "\nTwo mods share a key: open this to fix it." : "");
        s_button.Modulate = clash ? new Color(1f, 0.8f, 0.5f) : Colors.White;
    }

    sealed class MenuView
    {
        static readonly Color Accent = new(0.886f, 0.694f, 0.361f);
        static readonly Color Muted = new(0.60f, 0.64f, 0.70f);
        static readonly Color Text = new(0.91f, 0.93f, 0.95f);
        static readonly Color Card = new(0.071f, 0.110f, 0.145f);
        static readonly Color Line = new(0.145f, 0.200f, 0.250f);

        readonly CanvasLayer _layer;
        readonly VBoxContainer _list;
        readonly Label _status;

        public bool Visible
        {
            get => _layer.Visible;
            set => _layer.Visible = value;
        }

        public MenuView()
        {
            _layer = new CanvasLayer { Layer = 130, Name = "ModLoaderForMacOSMenu", Visible = false };
            var root = new Control { MouseFilter = Control.MouseFilterEnum.Ignore };
            root.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            _layer.AddChild(root);

            var dim = new ColorRect
            {
                Color = new Color(0, 0, 0, 0.58f),
                MouseFilter = Control.MouseFilterEnum.Stop
            };
            dim.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            root.AddChild(dim);

            var center = new CenterContainer();
            center.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            root.AddChild(center);

            var panel = new PanelContainer { CustomMinimumSize = new Vector2(660, 0) };
            var panelStyle = new StyleBoxFlat
            {
                BgColor = new Color(0.051f, 0.078f, 0.106f),
                BorderColor = new Color(0.886f, 0.694f, 0.361f, 0.80f)
            };
            panelStyle.SetBorderWidthAll(1);
            panelStyle.SetCornerRadiusAll(12);
            panelStyle.ContentMarginLeft = 14;
            panelStyle.ContentMarginRight = 14;
            panelStyle.ContentMarginTop = 12;
            panelStyle.ContentMarginBottom = 12;
            panel.AddThemeStyleboxOverride("panel", panelStyle);
            center.AddChild(panel);

            var box = new VBoxContainer();
            box.AddThemeConstantOverride("separation", 9);
            panel.AddChild(box);

            var header = new HBoxContainer();
            var heading = new VBoxContainer();
            heading.AddThemeConstantOverride("separation", 0);
            var title = new Label { Text = "Mods" };
            title.AddThemeFontSizeOverride("font_size", 22);
            title.AddThemeColorOverride("font_color", Accent);
            heading.AddChild(title);
            var subtitle = new Label { Text = "Mod Loader for MacOS" };
            subtitle.AddThemeFontSizeOverride("font_size", 9);
            subtitle.AddThemeColorOverride("font_color", Muted);
            heading.AddChild(subtitle);
            header.AddChild(heading);
            header.AddChild(new Control { SizeFlagsHorizontal = Control.SizeFlags.ExpandFill });
            var close = new Button { Text = "Close" };
            close.Pressed += Close;
            header.AddChild(close);
            box.AddChild(header);

            var hint = new Label
            {
                Text = "Click a window's name to open it. Click its key to change it, or press Off to free it. "
                     + "Choices are kept in hotkeys.json.",
                AutowrapMode = TextServer.AutowrapMode.WordSmart
            };
            hint.AddThemeFontSizeOverride("font_size", 11);
            hint.AddThemeColorOverride("font_color", Muted);
            box.AddChild(hint);

            var group = new Label { Text = "MOD PANELS" };
            group.AddThemeFontSizeOverride("font_size", 9);
            group.AddThemeColorOverride("font_color", Muted);
            box.AddChild(group);

            var scroll = new ScrollContainer
            {
                CustomMinimumSize = new Vector2(0, 340),
                SizeFlagsVertical = Control.SizeFlags.ExpandFill
            };
            _list = new VBoxContainer { SizeFlagsHorizontal = Control.SizeFlags.ExpandFill };
            _list.AddThemeConstantOverride("separation", 4);
            scroll.AddChild(_list);
            box.AddChild(scroll);

            var footer = new HBoxContainer();
            _status = new Label { SizeFlagsHorizontal = Control.SizeFlags.ExpandFill };
            _status.AddThemeFontSizeOverride("font_size", 11);
            _status.AddThemeColorOverride("font_color", Muted);
            footer.AddChild(_status);
            var reset = new Button { Text = "Reset all keys" };
            reset.Pressed += ResetAll;
            footer.AddChild(reset);
            box.AddChild(footer);

            ((SceneTree)Engine.GetMainLoop()).Root.AddChild(_layer);
        }

        public void Open()
        {
            Visible = true;
            Rebuild();
        }

        public void Close()
        {
            Visible = false;
            s_capturing = null;
        }

        public void Rebuild()
        {
            if (!Visible) return;

            foreach (Node child in _list.GetChildren())
            {
                _list.RemoveChild(child);
                child.QueueFree();
            }

            foreach (ModWindow window in s_windows)
                _list.AddChild(Row(window));

            _status.Text = s_capturing != null
                ? "Press a key. Escape cancels."
                : s_windows.Any(window => SharingKey(window).Any())
                    ? "Two mods share a key. Change one of them."
                    : "F1 opens this menu. The menu key can be changed like any other.";
        }

        Control Row(ModWindow window)
        {
            var card = new PanelContainer();
            var cardStyle = new StyleBoxFlat { BgColor = Card, BorderColor = Line };
            cardStyle.SetBorderWidthAll(1);
            cardStyle.SetCornerRadiusAll(6);
            cardStyle.ContentMarginLeft = 10;
            cardStyle.ContentMarginRight = 8;
            cardStyle.ContentMarginTop = 6;
            cardStyle.ContentMarginBottom = 6;
            card.AddThemeStyleboxOverride("panel", cardStyle);

            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            card.AddChild(row);

            var info = new VBoxContainer { SizeFlagsHorizontal = Control.SizeFlags.ExpandFill };
            info.AddThemeConstantOverride("separation", 0);
            var open = new Button
            {
                Text = window.Title,
                TooltipText = window.Mod,
                Flat = true,
                Alignment = HorizontalAlignment.Left,
                SizeFlagsHorizontal = Control.SizeFlags.ExpandFill
            };
            open.AddThemeColorOverride("font_color", Text);
            open.AddThemeFontSizeOverride("font_size", 13);
            open.Pressed += window.Press;
            info.AddChild(open);

            var modName = new Label { Text = window.Mod };
            modName.AddThemeFontSizeOverride("font_size", 9);
            modName.AddThemeColorOverride("font_color", Muted);
            info.AddChild(modName);
            row.AddChild(info);

            string keyText = s_capturing == window
                ? "Press a key..."
                : window.Key.IsNone ? "Off" : window.KeyLabel;
            var key = new Button { Text = keyText, CustomMinimumSize = new Vector2(140, 0) };
            key.Pressed += () => BeginCapture(window);
            key.AddThemeColorOverride("font_color", s_capturing == window || !window.Key.IsNone ? Accent : Muted);
            if (SharingKey(window).Any()) key.Modulate = new Color(1f, 0.72f, 0.4f);
            row.AddChild(key);

            var off = new Button { Text = "Off" };
            off.Pressed += () => SetKey(window, KeyChord.None);
            row.AddChild(off);

            return card;
        }
    }
}
