# Unreal Engine 5.8 on Omarchy

Runbook and log for the Unreal Engine, Blender and neovim setup on the desktop,
written so the laptop can follow the same steps. Dates are when each thing was
done or found. The `unreal` and `nvim` features deliver the Hyprland rules,
the neovim config and `nvim-ue`; the rest is manual and listed here.

Machine this was built on: desktop, Ryzen 9 7950X, RTX 5080 on the NVIDIA open
driver, two 3440x1440 monitors stacked vertically, Hyprland 0.56 via uwsm.

## Layout

| Path | What |
|---|---|
| `~/software/UnrealEngine/5.8.3` | Epic's Linux binary release, extracted as-is |
| `~/software/blender-5.2.2-linux-x64` | Blender tarball, extracted as-is |
| `~/software/StarterContent57` | Starter Content sample project (library copy) |
| `~/UnrealProjects/` | projects |
| `~/.config/Epic/UnrealEngine/5.8/Saved/Config/LinuxEditor/` | per-user editor settings (not `Linux/`) |
| `~/.config/Epic/UnrealEngine/Install.ini` | engine registry: maps the id `UE_5.8` to the install path |
| `~/.config/Epic/UnrealEngine/Common/DerivedDataCache` | shader/asset cache, grows over time |
| `~/.cache/nvidia/GLCache` | NVIDIA pipeline cache (see env below) |

Editor logs: `<Project>/Saved/Logs/<Project>.log`, or
`~/.config/Epic/UnrealEngine/5.8/Saved/Logs/Unreal.log` when no project is
open. The engine resolves a relative `.uproject` path against its own binary
directory, so always pass an absolute path on a command line.

## Engine install (manual)

1. Extract the Linux release to `~/software/UnrealEngine/5.8.3`.
2. Register it so projects find it by id:
   ```ini
   # ~/.config/Epic/UnrealEngine/Install.ini
   [Installations]
   UE_5.8=/home/dalton/software/UnrealEngine/5.8.3
   ```
   Projects carry `"EngineAssociation": "5.8"`, which resolves through this.
3. App menu entry at `~/.local/share/applications/UnrealEngine-5.8.3.desktop`:
   ```ini
   [Desktop Entry]
   Name=Unreal Engine 5.8.3
   Comment=Unreal Editor
   Exec=env -u SDL_IM_MODULE -u QT_IM_MODULE XMODIFIERS=@im=none SDL_VIDEO_DRIVER=x11 /home/dalton/software/UnrealEngine/5.8.3/Engine/Binaries/Linux/UnrealEditor
   Path=/home/dalton/software/UnrealEngine/5.8.3/Engine/Binaries/Linux
   Icon=/home/dalton/software/UnrealEngine/5.8.3/Engine/Source/Runtime/Launch/Resources/Linux/UnrealEngine.png
   Terminal=false
   Type=Application
   Categories=Development;
   StartupWMClass=UnrealEditor
   ```
   Keep the `env` form: the project browser spawns a child editor process that
   must inherit these variables.

### Why those variables

`SDL_VIDEO_DRIVER=x11` (2026-10-01). UE 5.8 ships SDL 3.4.4 and defaults to
its native Wayland backend. On Hyprland that backend opens Save As at minimum
size, creates menus and tooltips as 1x1 windows at screen centre before moving
them (each one warps the cursor), never shows toast notifications, and spawns
its notification windows as untitled top-levels that steal focus and freeze the
pointer. Epic's own SDL3 doc says pure Wayland is "unusable" for the editor and
XWayland "works as normal"; every Linux forum thread converges on this same
variable. Confirmed with `-LogCmds="LogLinuxWindowType Verbose"`.

Retired: `UE_NORELATIVEMOUSEMODE=1` (added 2026-10-04, removed 2026-10-06).
It was added because spin-box drags moved only 0.995 to 1.005; it makes
Unreal skip SDL relative mouse mode. But without relative mode nothing
captures the cursor during Play, so mouse-look stops at the window edge
(Hyprland `confine_pointer` keeps the cursor in the window but a pinned
cursor yields no deltas). After the input-method bypass below went in, spin
boxes and Play both work with relative mode on, so the variable and the
confine rule were dropped. Do not reintroduce it.

`XMODIFIERS=@im=none`, `SDL_IM_MODULE` and `QT_IM_MODULE` unset (2026-10-04).
Omarchy runs fcitx5 and exports `XMODIFIERS=@im=fcitx` and `SDL_IM_MODULE=fcitx`
session-wide. Under XWayland SDL then opens an X Input Method context with
fcitx5 and every key press passes through it, not just text. Twice, all keys
to the editor died at the first text field of a session (Cmd console box;
renaming a converted material parameter) while the mouse kept working and
focus was verified correct. Restarting fcitx5 while the editor ran crashed it
in `Xutf8ResetIC` (`SDL_StartTextInput` <- `SDL_SetKeyboardFocus`), which
proved the path. With the IM disabled SDL creates a local context only and
the whole path is gone. Unreal has no use for an input method.

### Hyprland rules (tracked, `features/unreal/hypr.lua`)

- No `confine_pointer` rule any more (tried 2026-10-06 for the standalone
  Play window `<Game> Preview [NetMode: ...]`; only needed while
  UE_NORELATIVEMOUSEMODE was set). For reference: runtime toggling is not
  possible, `hl.dsp.window.set_prop` rejects `confine_pointer` and
  `hyprctl setprop` no longer exists in 0.56; `hyprctl eval` runs Lua.
- The untitled-helper rule no longer sets `no_focus`: under XWayland it made
  toast buttons unclickable (2026-10-06). Border/shadow/opacity parts remain.

- Untitled floating `UnrealEditor` windows: no border, no shadow, no blur, no
  dim, opaque. These are the two startup toast windows the editor
  creates before its main window exists; they are harmless and invisible. The
  match key is `float`, not `floating` (Hyprland 0.56).
- `focus_on_activate = false` for the class. Omarchy's
  `misc.focus_on_activate = true` otherwise warps the cursor every time a menu
  or dialog asks for activation. Same treatment as Battle.net and Telegram.
- Opacity override `"1 override 1 override 1 override"` for `UnrealEditor` and
  `[Bb]lender`, copied from the Firefox-on-YouTube rule.
- `hl.env` for `__GL_SHADER_DISK_CACHE_SIZE=10737418240` and
  `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1`. The NVIDIA pipeline cache defaults
  to a 1 GB cap with eviction; Unreal alone exceeds it, so pipelines recompile
  every session and the editor logs `LogPSOHitching` stalls (150 in the first
  15 s). `env` entries are read at Hyprland startup only: log out and in.
  Verify with `systemctl --user show-environment | grep __GL_`. Harmless on a
  non-NVIDIA machine.

Known cosmetic issue: Hyprland presents stacked monitors to XWayland side by
side (6880x1440), so the two startup toasts land one monitor-width off the left
edge. Hyprland has no option for XWayland output layout. Toasts raised after
startup (undo, autosave, compile) display correctly. On a single-monitor laptop
this does not apply.

## Neovim as the source editor

Tracked by this repo:

- `features/nvim/files/.config/nvim/lua/plugins/unrealengine.lua`: `mbwilding/UnrealEngine.nvim`,
  `engine_path`, the launch variables in `environment_variables`, keys under
  `<leader>U` (`<leader>u` is the UI Toggles group).
- `features/nvim/files/.config/nvim/lua/plugins/which-key.lua`: the `[U]nreal` group.
- `features/nvim/files/.config/nvim/lua/plugins/lsp/mason.lua`, `formatting.lua`,
  `treesitter.lua`: clangd, clang-format, cpp parser (commit `13654be`).
- `features/unreal/files/.local/bin/nvim-ue`: re-pairs a new neovim with a running editor.

Manual, once per machine:

1. Open neovim so lazy installs the plugin and Mason installs clangd.
2. Build the accessor plugin. Do **not** use `build_engine()` / the README's
   `build` hook: the plugin decides "source engine" by whether `Build.sh`
   exists, and the binary install ships it, so it would try to recompile the
   whole editor. Either press `<leader>Up`, or run what it runs:
   ```sh
   ~/software/UnrealEngine/5.8.3/Engine/Build/BatchFiles/RunUAT.sh BuildPlugin \
     -Plugin=$HOME/.local/share/nvim/lazy/UnrealEngine.nvim/Plugins/NeovimSourceCodeAccess/NeovimSourceCodeAccess.uplugin \
     -Package=$HOME/.local/share/nvim/unrealengine/NeovimSourceCodeAccess \
     -TargetPlatforms=Linux
   ```
   About 30 s with the bundled clang.
3. Symlink the result into **Marketplace**, not Developer:
   ```sh
   mkdir -p ~/software/UnrealEngine/5.8.3/Engine/Plugins/Marketplace
   ln -sfn ~/.local/share/nvim/unrealengine/NeovimSourceCodeAccess \
     ~/software/UnrealEngine/5.8.3/Engine/Plugins/Marketplace/NeovimSourceCodeAccess
   ```
   A binary engine uses a precompiled rules assembly for `Engine/Plugins`; any
   new plugin elsewhere makes UBT fail with "Expecting to find a type ...
   NeovimSourceCodeAccess in UE5Rules". `Engine/Plugins/Marketplace` is
   compiled separately. `<leader>Up` recreates the Developer link, so move it
   again after any rebuild. An engine update removes the link.
4. With the editor closed, set the preference in
   `~/.config/Epic/UnrealEngine/5.8/Saved/Config/LinuxEditor/EditorSettings.ini`
   (the editor rewrites this file on exit):
   ```ini
   [/Script/SourceCodeAccess.SourceCodeAccessSettings]
   PreferredAccessor=NeovimSourceCodeAccessor
   ```
   Or pick Neovim in Edit > Editor Preferences > General > Source Code.

How it pairs: the accessor reads `$NVIM` once at editor start and sends every
request as `nvim --server $NVIM --remote <file>`. So launch the editor from
neovim with `<leader>Uo`; a menu launch has no `$NVIM` and open requests just
log a warning. If that neovim closes, `nvim-ue` from the project directory
starts a new one listening on the same socket and the pairing resumes. Only one
neovim can own the socket.

clangd: `<leader>Ug` (or opening neovim in a project directory, via
`auto_generate`) runs UBT in `GenerateClangDatabase` mode. The database is
written to the engine root and symlinked into the project, so only the most
recently generated project is valid; switching projects regenerates on open.

Gotchas met:

- Reformatting a header so `GENERATED_BODY()` changes line shows "a type
  specifier is required" until a build regenerates the `.generated.h`.
- On Linux the editor's Compile button and an external
  `Build.sh <Project>Editor Linux Development <abs .uproject> -game -engine`
  both hot reload: UBT writes a `-0001` module and the editor swaps it in.
- 5.8 engine bug (also on Windows): in the undocked Content Drawer the folder
  tree sometimes loses its icons and rejects drag-and-drop. Dock it ("Dock in
  Layout") or use Window > Content Browser; or move via the Cmd box with
  `py unreal.EditorAssetLibrary.rename_asset('/Game/A', '/Game/Materials/A')`.
- Dragging between two overlapping Unreal windows (e.g. main window to a
  floating Material Editor) drops on the main window: Slate tracks its own
  stacking and marks the window you clicked as topmost, while Hyprland keeps
  floating windows above tiled ones. Use the target window's own Content
  Drawer, dock the editor, stop the overlap, or select the texture and T+click
  in the graph.
- The TopDown C++ template's Blueprints (`BP_TopDownGameMode`,
  `BP_TopDownController`, `BP_TopDownCharacter`) parent to engine classes, not
  to the generated project C++ classes. C++ overrides there do nothing until
  the Blueprint is reparented (Class Settings > Parent Class). Check with
  `strings X.uasset | grep /Script/`.

## Blender

Extract the tarball into `~/software/`. Its bundled `blender.desktop` assumes a
system install, so copy it with absolute paths:

```sh
B=~/software/blender-5.2.2-linux-x64
sed -e "s|^Exec=blender|Exec=$B/blender|" -e "s|^Icon=blender$|Icon=$B/blender.svg|" \
  "$B/blender.desktop" > ~/.local/share/applications/blender.desktop
ln -sfn "$B/blender" ~/.local/bin/blender
```

Upgrade: extract the new version beside the old, re-point the symlink and the
two desktop-entry lines.

## Fab plugin (Megascans, MF_Tiling)

Not bundled with the Linux engine release and there is no launcher on Linux.
Download the version-matched zip from unrealengine.com/linux (Epic login),
e.g. `Linux_Fab_5.8.0_0.0.13.zip`. It is laid out as `Engine/Plugins/Fab/...`
with prebuilt Linux binaries; extract it and move the `Fab` folder to
`Engine/Plugins/Marketplace/Fab` (same reason as the Neovim accessor: a new
engine plugin anywhere else breaks UBT on a binary install). Check that
`Binaries/Linux/UnrealEditor.modules` `BuildId` equals the engine's in
`Engine/Binaries/Linux/UnrealEditor.modules` (55116800 for 5.8.3); if not,
rebuild with `RunUAT.sh BuildPlugin` like the Neovim one. Enabled by default.
Installed 2026-10-04. Verified working.

The plugin mounts its own content at `/Fab/`: `MaterialFunctions/QMF_*`
(QMF_Tiling, QMF_NormalAdjustments, ...) and `Materials/Standard/M_MS_Base_*`
master materials. Tutorials older than Fab use `MF_Tiling`, which was a
project-side function (`/Game/MSPresets/MS_DefaultMaterial/Functions/`) that
the old Bridge importer created and that carried Scalar Parameter nodes
inside, so material instances showed Tiling sliders for free. `QMF_Tiling`
has three plain function inputs (Tiling, Offset X, Offset Y) and no
parameters, so an instance shows nothing until the material feeds those inputs
from its own Scalar Parameter nodes. Do that; name the main one `Tiling`.

## Sample / complete projects (Stack O Bot etc.)

No native Linux route (checked 2026-10-06). The Fab plugin's downloader
rejects any pack containing a `.uproject` ("Invalid pack",
`FabDownloader.cpp`), so Window > Fab only ever adds assets to an open
project. legendary / Heroic (`legendary list --include-ue`) read the pre-Fab
Unreal entitlement list and never see Fab claims (still true in legendary
0.21.1, 2026-09). The Epic launcher's "Create Project" is the only path.

Tried and abandoned: the Epic launcher under umu/GE-Proton (`~/Games/epic`).
It installs and renders with `-OpenGL`, signs in and lists the Fab library,
but Create Project is gated on Epic Online Services, whose MSI dies in a .NET
custom action (`SFXCA: Failed to get requested CLR info`, EOS-ERR-1603) even
with `winetricks -q dotnet48` installed and verified. Not worth more time.

What worked: Omarchy's Windows VM (`omarchy windows vm install`, Dockur
image). Inside it, install the Epic launcher, claim the project on fab.com,
Unreal Engine > Library > Engine Versions > install 5.8 with all optional
components unticked (needed: Create Project only lists launcher-installed
engines), then Fab Library > Create Project onto `Z:` (the host's
`~/Windows`). The launcher writes `<Name>_<ver>/data/<Name>.uproject` plus a
`manifest`; move the `data` folder to `~/UnrealProjects/<Name>` and normalise
modes (the container stamps 2777/setgid). Stack O Bot came out as a
5.8-associated Blueprint project, no conversion needed.

VM gotchas: resources change by re-running `omarchy windows vm install` with
the same disk size and credentials (disk persists in `~/.windows`); but the
container leaves `~/Windows` at mode 2700 and the config writer silently
fails unless it is exactly 700, so run `chmod g-s ~/Windows` first (numeric
`chmod 0700` does not clear the bit). Growing the disk needs the C: partition
extended in Windows Disk Management afterwards. Stop with
`omarchy windows vm stop`; `remove` deletes the disk.

## Starter Content

Not included in 5.7+. The Fab download (`StarterContent57.zip`) is a complete
project, not a `.upack`, so it does not go in `FeaturePacks/`. Extract once to
`~/software/StarterContent57` and copy `Content/StarterContent` into a
project's `Content/` folder; it is self-referencing under
`/Game/StarterContent/` so no migration step is needed. About 640 MB per
project.

## Resolved: keyboard goes dead (2026-10-01, 2026-10-04)

See the `XMODIFIERS=@im=none` entry above. Symptom: no keyboard input to the
editor at all (no text, no W in the viewport), mouse fine, window focused in
both Hyprland and X11, onset at the first text field of the session. Cause:
fcitx5's XIM frontend in SDL's X11 keyboard path. Fix: the IM bypass on both
launch paths. Status: applied 2026-10-04 afternoon; the first properly
launched session worked. Watch for recurrence.

Never restart fcitx5 by hand on Omarchy. It runs as
`omarchy-fcitx5.service` with `Restart=always`, `RestartSec=2`; a manual
`fcitx5 -r` leaves an orphan owning the D-Bus name and the service then fails
every two seconds (340+ restarts), each attempt touching XWayland's input
method registration, which itself kills X11 keyboard input. Recover with
`kill <orphan pid>` and `systemctl --user restart omarchy-fcitx5.service`,
with the editor closed: stopping fcitx5 under an editor whose keyboard path
still runs through XIM segfaults it in `Xutf8ResetIC`.

After changing `environment_variables` in the neovim spec, restart neovim
before `<leader>Uo`; a running instance keeps the old table.

## Log

- 2026-10-01: engine extracted to `~/UnrealEngine/5.8.3`, `.desktop` added.
  Diagnosed the Wayland backend problems above; moved to X11. Two Hyprland
  rules. Toasts confirmed working under XWayland later that day.
- 2026-10-01: clangd/clang-format/cpp parser added to neovim (`13654be`).
  UnrealEngine.nvim installed, accessor built, Marketplace symlink,
  preference set, keys moved to `<leader>U` after a clash, `nvim-ue` added.
  Verified open-in-neovim end to end. First hot reload of a C++ game mode.
- 2026-10-01: engine moved to `~/software/UnrealEngine/5.8.3`; Install.ini,
  launcher, nvim spec and clangd database updated. Blender 5.2.2 extracted,
  desktop entry and PATH symlink. Starter Content extracted and copied into
  BadDecisionsTutorial.
- 2026-10-04: opacity rules for Unreal and Blender. PSO hitch diagnosis; NVIDIA
  shader cache env added, live after reboot. Slider drag bug diagnosed;
  `UE_NORELATIVEMOUSEMODE=1` added to both launch paths. Keyboard dead a second
  time; plan above. Discovered `sed -i` had detached
  `~/.features/unreal/hypr.lua` from its repo symlink on 10-01; restored and
  committed (`e921aaf`). Prefer editing the repo path or `sed -i --follow-symlinks`.
- 2026-10-04: keyboard died a third time; `fcitx5 -r` crashed the editor in
  `Xutf8ResetIC`, confirming fcitx5's XIM in the keyboard path. IM bypass added
  to the launcher and the neovim spec. Runbook written (`features/unreal/README.md`).
  The hand restart also put `omarchy-fcitx5.service` into a 2 s restart loop
  that broke keys a fourth time; fixed by killing the orphan. First session
  with the bypass confirmed working.
- 2026-10-06: Fab plugin installed; Stack O Bot obtained via the Windows VM;
  toasts made clickable (no_focus removed); UE_NORELATIVEMOUSEMODE retired
  after confirming sliders and Play both work with relative mode on.

## Laptop checklist

1. Add `unreal` to the machine's profile and run `./install.sh`. That delivers the Hyprland rules and env,
   the neovim config and `nvim-ue`.
2. Engine: extract, `Install.ini`, `.desktop` (section above).
3. Neovim: open once, then steps 2 to 4 of the neovim section.
4. Blender and Starter Content if wanted.
5. Log out and in for the `hl.env` entries. On a non-NVIDIA laptop they are
   inert.
6. The `.desktop` files and `Install.ini` hardcode `/home/dalton`; adjust if
   the username differs.
