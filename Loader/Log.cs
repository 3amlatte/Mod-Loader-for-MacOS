using System;
using System.Collections.Generic;
using System.IO;

namespace MelvorModLoader;

/// <summary>Small plain-text log, rewritten each start.</summary>
public static class Log
{
    static readonly object Gate = new();

    public static string FilePath { get; private set; } =
        Path.Combine(Path.GetTempPath(), "ModLoaderForMacOS.log");

    internal static void StartNewSession(string gameRoot)
    {
        var places = new List<string>();
        if (OperatingSystem.IsMacOS()) places.Add(Bootstrap.SupportDir());
        places.Add(gameRoot);
        places.Add(Path.GetTempPath());

        foreach (string place in places)
        {
            try
            {
                Directory.CreateDirectory(place);
                string path = Path.Combine(place, "ModLoaderForMacOS.log");
                File.WriteAllText(path, string.Empty);
                FilePath = path;
                return;
            }
            catch
            {
                // Try the next writable place.
            }
        }
    }

    public static void Write(string message)
    {
        try
        {
            lock (Gate)
                File.AppendAllText(FilePath, $"[{DateTime.Now:HH:mm:ss}] {message}\n");
        }
        catch
        {
            // Logging must never break the game.
        }
    }
}
