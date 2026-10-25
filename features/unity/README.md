# Unity 6 on Omarchy, with Neovim as the script editor

Runbook in the style of `features/unreal/README.md`. The `unity` feature
delivers the Hyprland rule and the Unity analyzer dll; the `nvim` feature
delivers Roslyn. The Unity side is per project and per machine, listed under
"By hand" below.

Built on the desktop, 2026-10-15, Unity 6000.6.5f1 from Unity Hub, Hyprland
0.56, Neovim 0.12.5, Ghostty.

## Layout

| Path | What |
|---|---|
| `~/Unity/Hub/Editor/<version>` | editors installed by Unity Hub |
| `~/UnityProjects/` | projects |
| `~/.config/unity3d/prefs` | editor preferences, including the Neovim package's settings (`NvimUnityConfigJson`) |
| `~/.config/unity3d/Editor.log` | editor log; `Editor-prev.log` is the previous run |
| `~/.local/share/unity-analyzers/Microsoft.Unity.Analyzers.dll` | fetched by `features/unity/setup` |
| `/tmp/nvimsocket` | the Neovim server the Unity package talks to |
| `~/.local/share/unity/com.dalton.refresh-on-save` | local UPM package from this feature (`linkdirs`, so Unity's `.meta` files land in the repo) |

## How the pieces fit

- **Unity package `com.walcht.ide.neovim`** (per project). Registers Neovim
  as an External Script Editor, generates the `.sln` and `.csproj` files
  Roslyn needs (the Visual Studio and Rider packages only do that for their
  own IDE), and opens files. First open: launches a terminal running
  `nvim <file> --listen /tmp/nvimsocket`. Later opens: `nvim --server
  /tmp/nvimsocket --remote-tab <file>`, then a jump to the line, then focus
  via `hyprctl` on the window titled `nvimunity-<id>`. It starts nvim with
  `--cmd` globals carrying the diagnostic scopes chosen in its settings
  window; `after/lsp/roslyn.lua` reads them.
- **Roslyn** (`features/nvim`): `seblyng/roslyn.nvim` starts Mason's
  `roslyn-language-server` for every `.cs` buffer and picks the `.sln` in
  the project root. mason-lspconfig excludes lspconfig's own `roslyn_ls`,
  which would otherwise attach a second copy. `csharp_ls` was dropped for
  this on 2026-10-15.
- **Refresh on save** (`com.dalton.refresh-on-save`, per project). Unity on
  Linux rescans `Assets/` only when its window regains focus, and under
  Hyprland that signal never arrives (hyprwm/Hyprland issue 7333, still open
  in effect on 0.56 in 2026-09; fine on GNOME, KDE, Niri). Without it every
  save needs Ctrl+R. The package watches `Assets/` with a FileSystemWatcher
  and calls `AssetDatabase.Refresh()` a second after the last write, outside
  Play Mode and compiles, and stays quiet when Auto Refresh is off in
  Preferences > Asset Pipeline.
- **Microsoft.Unity.Analyzers**: pointed at from the package's settings; it
  adds the dll to every generated `.csproj`, so Roslyn stops flagging Unity
  message methods as unused and reports Unity-specific issues.

## By hand

Per project:

1. Window > Package Management > Package Manager > `+` > Install package from
   git URL, or add it to `Packages/manifest.json` directly. Pin the commit:
   Hyprland focus landed after the last tag (v1.3.0).
   ```json
   "com.walcht.ide.neovim": "https://github.com/walcht/com.walcht.ide.neovim.git#54fb26c29f5fc35cab1cb5f7be49e326813b251e"
   ```
   Restart the editor after it resolves. Add the refresh package the same
   way (absolute `file:` path; the manifest does not expand `~`):
   ```json
   "com.dalton.refresh-on-save": "file:/home/dalton/.local/share/unity/com.dalton.refresh-on-save"
   ```
2. Edit > Preferences > External Tools > External Script Editor: `Neovim
   v0.12.x`. Tick the "Generate .csproj files for" boxes you want LSP
   coverage of (all is fine for a small project). "Regenerate project files"
   writes the `.sln` and `.csproj` files into the project root.
3. If Neovim is not in the dropdown, set the executable path
   (`/usr/bin/nvim`) in the top menu Neovim > Settings, then Assets >
   Reimport All.

Per machine, in Neovim > Settings (stored in `~/.config/unity3d/prefs`, so
each machine and each editor version needs it once):

4. Terminal launch command. Do not leave this on autodetect: the package's
   built-in Ghostty template for Linux opens `--command='` and never closes
   the quote, so Mono's argument parser throws before Ghostty runs
   (`Win32Exception ... ApplicationName='ghostty' ... Native error= Success`
   in the Console, 2026-10-15). Set it to Ghostty's `-e` form, which takes
   the rest of the line as argv and needs no nested quoting. `{filePath}` is
   substituted already double-quoted, so leave it bare:
   - command: `ghostty`
   - args:
     ```
     --title=nvimunity-{instanceId} -e {app} {filePath} --listen {serverSocket} --cmd ":lua _G.nvim_unity_user_supplied_project_root_dir='{projectRootDir}' _G.nvim_unity_analyzer_diagnostic_scope='{analyzerDiagnosticScope}' _G.nvim_unity_compiler_diagnostic_scope='{compilerDiagnosticScope}'"
     ```
     The `--cmd` part is what the built-in templates append; it carries the
     settings window's diagnostic scopes into `after/lsp/roslyn.lua`.
5. Analyzer: Browse to
   `~/.local/share/unity-analyzers/Microsoft.Unity.Analyzers.dll`, Apply,
   then Regenerate project files.

Verify: double-click a script in the Project window. A Ghostty window titled
`nvimunity-…` opens with the file. Double-click another script: it opens in
the same window as a new tab. In nvim, `:LspInfo` shows one client, `roslyn`,
with the project's `.sln` as target; `:checkhealth roslyn` if not.

## Hyprland rules (`features/unity/hypr.lua`)

- Unity Editor: opacity override, as for Unreal.
- The Ghostty window the package launches (`initial_title` `nvimunity-<pid>`):
  floating, 1920x1080, centered, so it overlays the editor instead of tiling
  into it. Hyprland regexes match the whole string, hence the trailing `.*`.

## Gotchas

- `nvim` and `dotnet` must resolve from Unity's own environment, not just an
  interactive shell. On Omarchy the session PATH already includes the mise
  shims and `~/.local/bin` (`systemctl --user show-environment`), so nothing
  to do; on another distro the package README says to append to `~/.profile`.
- `.slnx`: `dotnet new sln` now writes the XML solution format; Unity still
  writes `.sln`. roslyn.nvim handles both.
- The package's settings include `AnalyzerDiagnosticScope` and
  `CompilerDiagnosticScope` (default `openFiles`). `fullSolution` is slow on
  anything but a small project.
- Unity regenerates `.csproj` files on asset changes; the `Library/` and
  generated files are already in Unity's default `.gitignore`.
- Window focus uses `hyprctl eval` with `initialtitle:nvimunity-<id>`, so a
  renamed title (e.g. a plugin that sets the terminal title) breaks focus,
  not opening.
- Scripts save and refresh but never compile, the status bar (bottom right)
  shows a lock icon ("Assemblies are currently locked"), and Play logs
  `Entering playmode with assembly reload locked`. The lock is native
  (`Application::CanReloadAssemblies`); the only managed callers of
  `LockReloadAssemblies` are Unity's own and none run here. Seen 2026-10-15
  and twice on 2026-10-25 (saves at 10:58 and 11:55, compiles at 11:04 and
  12:02, so about 7 minutes each, released with nothing in the log and no
  user action; mouse, clicks, Ctrl+R, focus cycling, and
  Escape were all tried without effect). Not Play Mode, not a package, not
  the licensing client (its requests are answered in milliseconds; the
  entitlement check right before each compile is the compile starting).
  Known native holders are popups, drags, and modals; what held it is
  unknown. Waiting it out works; a restart is faster. Next occurrence, run
  this in a terminal first so the log gets wall-clock times:
  ```
  tail -F ~/UnityProjects/*/Logs/Editor.log | grep --line-buffered -E 'Requested script compilation|Starting: .*bee_backend|reload locked' | while read -r l; do echo "$(date +%T) $l"; done
  ```
  Unity parks its untitled helper windows (dropdowns, tooltips) off-screen
  on purpose; a compositor rule that drags them into view (white squares
  with the editor's class as title) trips the same lock, so `hypr-tweaks`'
  recentre hook skips untitled windows (2026-10-15).

## Not done yet

- Debugging: `walcht/unity-dap` via nvim-dap (the Unity Editor listens on
  `56000 + pid % 1000`; see `Editor.log` for `monoOptions ... address=`).
- Formatting: Roslyn's own formatter works through `vim.lsp.buf.format`;
  csharpier not wired in.

## Laptop checklist

1. `unity` in the profile, `./install.sh` (Hyprland rule, analyzer dll),
   `nvim` already brings Roslyn.
2. Unity Hub, same editor version, open the project (the package is in its
   manifest).
3. Steps 2 to 5 above.
