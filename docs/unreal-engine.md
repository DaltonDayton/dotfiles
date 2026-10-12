# Unreal Engine 5.8 on Omarchy

Runbook and log for the Unreal Engine, Blender and neovim setup on the desktop,
written so the laptop can follow the same steps. Dates are when each thing was
done or found. Anything under `~/.config/hypr`, `~/.config/nvim` or
`~/.local/bin` is tracked by this repo and arrives with `./install.sh`; the
rest is manual and listed here.

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
   must inherit both variables.

### Why those two variables

`SDL_VIDEO_DRIVER=x11` (2026-10-01). UE 5.8 ships SDL 3.4.4 and defaults to
its native Wayland backend. On Hyprland that backend opens Save As at minimum
size, creates menus and tooltips as 1x1 windows at screen centre before moving
them (each one warps the cursor), never shows toast notifications, and spawns
its notification windows as untitled top-levels that steal focus and freeze the
pointer. Epic's own SDL3 doc says pure Wayland is "unusable" for the editor and
XWayland "works as normal"; every Linux forum thread converges on this same
variable. Confirmed with `-LogCmds="LogLinuxWindowType Verbose"`.

`XMODIFIERS=@im=none`, `SDL_IM_MODULE` and `QT_IM_MODULE` unset (2026-10-04).
fcitx5's XIM sits in SDL's X11 keyboard path and killed all keyboard input at
the first text field of a session; see the resolved issue below. Keep the
bypass on every launch path (desktop entry, terminal, neovim spec).

Do not set `UE_NORELATIVEMOUSEMODE=1`. It was added 2026-10-04 for sluggish
spin-box drags and removed 2026-10-06: without relative mouse mode, Play cannot
capture the cursor, so mouse-look stops at the window edge, and Hyprland's
`confine_pointer` does not help. Spin boxes drag correctly with relative mode
once the fcitx5 bypass is in place. The editor resolves a relative `.uproject`
path against its binary dir, so always pass an absolute path.

### Hyprland rules (tracked, `config/hypr/hyprland.lua`)

- Untitled floating `UnrealEditor` windows: no border, no shadow, no blur, no
  dim, opaque, `no_focus`. These are the two startup toast windows the editor
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

- `config/nvim/lua/plugins/unrealengine.lua`: `mbwilding/UnrealEngine.nvim`,
  `engine_path`, both launch variables in `environment_variables`, keys under
  `<leader>U` (`<leader>u` is the UI Toggles group).
- `config/nvim/lua/plugins/which-key.lua`: the `[U]nreal` group.
- `config/nvim/lua/plugins/lsp/mason.lua`, `formatting.lua`,
  `treesitter.lua`: clangd, clang-format, cpp parser (commit `13654be`).
- `home/.local/bin/nvim-ue`: re-pairs a new neovim with a running editor.

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

## Starter Content

Not included in 5.7+. The Fab download (`StarterContent57.zip`) is a complete
project, not a `.upack`, so it does not go in `FeaturePacks/`. Extract once to
`~/software/StarterContent57` and copy `Content/StarterContent` into a
project's `Content/` folder; it is self-referencing under
`/Game/StarterContent/` so no migration step is needed. About 640 MB per
project.

## Resolved: keyboard goes dead (2026-10-01, 2026-10-04)

Twice, all keyboard input to the editor stopped (no text, no W in the
viewport) while the mouse kept working. Both times it began at the first text
field of the session. Cause: the editor inherited `SDL_IM_MODULE=fcitx` and
`XMODIFIERS=@im=fcitx`, so SDL handed every key to fcitx5 over XIM. Proved on
2026-10-04 when `fcitx5 -r` crashed the editor in `Xutf8ResetIC`. Both launch
paths now carry the bypass:

```sh
env -u SDL_IM_MODULE -u QT_IM_MODULE XMODIFIERS=@im=none SDL_VIDEO_DRIVER=x11 \
  ~/software/UnrealEngine/5.8.3/Engine/Binaries/Linux/UnrealEditor /abs/path/Project.uproject
```

Never restart fcitx5 while an editor launched without the bypass is running.

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
  time; `fcitx5 -r` crashed the editor in `Xutf8ResetIC`, confirming fcitx5's
  XIM. Bypass added to both launch paths. Discovered `sed -i` had detached
  `~/.config/hypr/hyprland.lua` from its repo symlink on 10-01; restored and
  committed (`e921aaf`). Prefer editing the repo path or `sed -i --follow-symlinks`.
- 2026-10-06: `UE_NORELATIVEMOUSEMODE=1` removed from both launch paths; it
  stopped Play from capturing the cursor. Spin boxes are fine without it.
- 2026-10-12: this file was lost uncommitted and restored from the session
  transcript; `~/UnrealProjects/CLAUDE.md` now imports it.

## Laptop checklist

1. Clone the repo, `./install.sh`. That delivers the Hyprland rules and env,
   the neovim config and `nvim-ue`.
2. Engine: extract, `Install.ini`, `.desktop` (section above).
3. Neovim: open once, then steps 2 to 4 of the neovim section.
4. Blender and Starter Content if wanted.
5. Log out and in for the `hl.env` entries. On a non-NVIDIA laptop they are
   inert.
6. The `.desktop` files and `Install.ini` hardcode `/home/dalton`; adjust if
   the username differs.
