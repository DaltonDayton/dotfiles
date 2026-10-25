using System.IO;
using System.Threading;
using UnityEditor;
using UnityEngine;

// Unity on Linux rescans Assets/ only when its window regains focus, and under
// Hyprland that signal never arrives (hyprwm/Hyprland issue 7333), so saves in
// an external editor sit unnoticed until Ctrl+R. Watch the directory instead
// and refresh about a second after the last write, on the main thread, never
// during Play Mode or a compile. Honours Preferences > Asset Pipeline > Auto
// Refresh: off means off.
[InitializeOnLoad]
static class RefreshOnSave
{
    const double DebounceSeconds = 1.0;

    static readonly FileSystemWatcher Watcher;
    static int pending;          // set from watcher threads, consumed on the main thread
    static double dueAt = -1;    // timeSinceStartup at which to refresh; <0 means nothing queued

    static RefreshOnSave()
    {
        Watcher = new FileSystemWatcher(Application.dataPath)
        {
            IncludeSubdirectories = true,
            NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.DirectoryName,
        };
        Watcher.Changed += OnChange;
        Watcher.Created += OnChange;
        Watcher.Deleted += OnChange;
        Watcher.Renamed += OnChange;
        Watcher.EnableRaisingEvents = true;

        EditorApplication.update += Update;
        AssemblyReloadEvents.beforeAssemblyReload += Watcher.Dispose;
    }

    static void OnChange(object sender, FileSystemEventArgs e)
    {
        // .meta files are Unity's own writes; dotfiles are editor swap/backup files.
        if (e.Name.EndsWith(".meta") || Path.GetFileName(e.Name).StartsWith(".")) return;
        Interlocked.Exchange(ref pending, 1);
    }

    static void Update()
    {
        if (Interlocked.Exchange(ref pending, 0) == 1)
            dueAt = EditorApplication.timeSinceStartup + DebounceSeconds;
        if (dueAt < 0 || EditorApplication.timeSinceStartup < dueAt) return;
        if (EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling || EditorApplication.isUpdating) return;
        if (EditorPrefs.GetInt("kAutoRefreshMode", 1) == 0) { dueAt = -1; return; }

        dueAt = -1;
        AssetDatabase.Refresh();
    }
}
