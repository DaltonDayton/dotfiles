# `hyprland` Module — Design

## Context

The user is rebuilding their Hyprland desktop environment from scratch in the `quill` repo. The old setup at `~/.dotfiles/arch/modules/hyprland/` worked but accreted complexity over time, including a custom Python+Jinja2 multi-theme switcher that's now dead. The new direction uses **`matugen`** (a Material You wallpaper-driven color generator) for theming, with templates that emit color files into `~/.config/<app>/colors/` for each app to source.

Work has been in progress under `~/.config/*_new/` directories with a pair of swap scripts (`use-new-config.sh`, `use-primary-config.sh`). This spec replaces that workflow with a proper quill module.

The user wants to **set up the framework**, not port everything wholesale. The spec defines the module's shape, conventions, and integration points; subsequent commits flesh out individual app configs (seeded from the `_new` dirs).

## Goal

A single `modules/hyprland/` mega-module that owns the entire Hyprland desktop session. Bringing up a fresh machine via `quill apply hyprland` should:

1. Install all packages required for a Hyprland session.
2. Symlink config dirs into `~/.config/`.
3. Enable the bluetooth and SDDM services.
4. Run the imperative bits — `/etc/sddm.conf`, SDDM theme deployment, voxtype interactive setup, first-run matugen render against a bundled default wallpaper.

Subsequent applies are no-ops. Theme switching at runtime is **outside quill** — a user keybind invokes a script that calls `matugen` directly.

No new quill Go code is required.

## Module identity

- **Name:** `hyprland`
- **Tags:** `["essential", "desktop"]`
- **Depends on:** `fonts`
- **Replaces:** the standalone `modules/kitty/` module (which gets deleted; kitty configs fold into this module)

### Apps owned by this module

| App | Role | Lives at |
|---|---|---|
| `hypr` | window manager, idle, lock, paper, keybindings, windowrules | `files/hypr/` → `~/.config/hypr/` |
| `waybar` | status bar | `files/waybar/` → `~/.config/waybar/` |
| `swaync` | notification center | `files/swaync/` → `~/.config/swaync/` |
| `kitty` | terminal | `files/kitty/` → `~/.config/kitty/` |
| `matugen` | wallpaper-driven theming engine | `files/matugen/` → `~/.config/matugen/` |
| `voxtype` | voice dictation | `files/voxtype/` → `~/.config/voxtype/` |
| `wallpapers` | wallpaper assets including the bundled default | `files/wallpapers/` → `~/.config/wallpapers/` |
| `sddm-theme` | display manager theme | `files/sddm-theme/` → `/usr/share/sddm/themes/<name>/` (sudo cp, not symlink) |
| `cliphist` | clipboard manager | `~/.config/cliphist/config` written declaratively |
| `/etc/sddm.conf` | display manager system config | `files/sddm.conf` → `/etc/sddm.conf` (sudo symlink) |

### Out of scope

- Theme palettes / a theme switcher (the old Python+Jinja2 system stays dead).
- A wallpaper-switching script (lives in `files/hypr/scripts/` as a regular dotfile when written; not part of this spec).
- Anything not part of the active Hyprland session (`neovim`, `tmux`, `shell` stay in their own modules).
- Selecting the active waybar layout when multiple ship in `files/waybar/layouts/` (deferred to content work).
- Porting individual app configs beyond what already exists in `~/.config/*_new/`.

## Directory layout

```
modules/hyprland/
├── module.toml
├── install.sh
├── .gitignore                          # see below
├── files/
│   ├── hypr/                           # → ~/.config/hypr/
│   │   ├── hyprland.conf
│   │   ├── hypridle.conf
│   │   ├── hyprlock.conf
│   │   ├── hyprpaper.conf
│   │   ├── keybindings.conf
│   │   ├── windowrules.conf
│   │   ├── conf.d/
│   │   ├── monitors/
│   │   │   ├── default.conf
│   │   │   ├── desktop.conf
│   │   │   └── laptop.conf
│   │   ├── monitors.conf               # internal symlink, set by install.sh
│   │   └── scripts/                    # lowercased (was Scripts/ in old module)
│   ├── waybar/                         # → ~/.config/waybar/
│   ├── swaync/                         # → ~/.config/swaync/
│   ├── kitty/                          # → ~/.config/kitty/
│   ├── matugen/                        # → ~/.config/matugen/
│   │   ├── config.toml
│   │   └── templates/
│   ├── voxtype/                        # → ~/.config/voxtype/
│   │   ├── configs/
│   │   │   ├── default.toml
│   │   │   ├── desktop.toml
│   │   │   └── laptop.toml
│   │   └── config.toml                 # internal symlink, set by install.sh
│   ├── wallpapers/                     # → ~/.config/wallpapers/
│   │   ├── default.<ext>               # used for first-run matugen render
│   │   └── …other wallpapers…
│   ├── sddm-theme/                     # NOT symlinked — sudo cp -rT to /usr/share/sddm/themes/
│   │   ├── theme.conf.tmpl             # device parameters via host vars
│   │   └── …assets…
│   └── sddm.conf                       # → /etc/sddm.conf via sudo symlink
```

### Conventions

- `files/<app>/` is the unit of organization. The directory's contents mirror its `~/.config/<app>/` layout.
- **Whole-config device swaps** (`monitors`, `voxtype/configs`) use the `<app>/<variants>/<host>.conf` + internal-symlink pattern, with `install.sh` setting the symlink. Default + per-host variants ship in the repo.
- **Parameter-level device variation** (sddm theme settings, anything with only a couple varying values) uses `.tmpl` files with host vars from `hosts/<hostname>.toml`.
- `sddm-theme/` and `sddm.conf` don't get user-level symlinks — `install.sh` does the sudo work.
- `wallpapers/default.<ext>` is committed so first-run matugen on a fresh machine has something to render against.
- Scripts live in lowercased directories (`scripts/`, not `Scripts/`).

### `.gitignore` entries

```
files/hypr/monitors.conf
files/voxtype/config.toml
```

These are internal symlinks created by `install.sh` and must not be tracked.

## `module.toml` (declarative actions)

Everything that fits an existing quill action type lives here. Anything that needs sudo to write outside `$HOME`, interactive setup, or one-time generation moves to `install.sh`.

```toml
name = "hyprland"
description = "Hyprland desktop session: WM, bar, notifications, terminal, theming"
tags = ["essential", "desktop"]
depends_on = ["fonts"]

[[packages]]
manager = "pacman"
names = [
    "hyprland", "hyprpaper", "hypridle", "hyprlock", "hyprlauncher", "hyprpicker",
    "hyprpolkitagent", "qt5-wayland", "qt6-wayland",
    "waybar", "swaync", "rofi", "kitty",
    "sddm",
    "pipewire-pulse", "pavucontrol",
    "bluez", "bluez-utils", "blueman",
    "grim", "slurp", "satty", "wl-clipboard", "wf-recorder",
    "cliphist",
    "tesseract", "tesseract-data-eng",
    "xdg-utils", "desktop-file-utils", "shared-mime-info", "archlinux-xdg-menu",
    "jq", "btop",
]

[[packages]]
manager = "aur"
names = [
    "matugen-bin",
    "bibata-cursor-theme-bin",
    "grimblast-git",
    "voxtype", "wtype",
]

[[symlinks]]
src = "files/hypr"
dst = "~/.config/hypr"

[[symlinks]]
src = "files/waybar"
dst = "~/.config/waybar"

[[symlinks]]
src = "files/swaync"
dst = "~/.config/swaync"

[[symlinks]]
src = "files/kitty"
dst = "~/.config/kitty"

[[symlinks]]
src = "files/matugen"
dst = "~/.config/matugen"

[[symlinks]]
src = "files/voxtype"
dst = "~/.config/voxtype"

[[symlinks]]
src = "files/wallpapers"
dst = "~/.config/wallpapers"

[[files]]
dst = "~/.config/cliphist/config"
content = "max-items=100\n"

[[services]]
scope = "system"
name = "bluetooth.service"
state = "enabled"

[[services]]
scope = "system"
name = "sddm.service"
state = "enabled"
```

The exact package list will be refined when porting; the shape is what matters here.

## `install.sh` (imperative escape hatch)

Runs after all declarative actions across all modules complete (per quill's contract). Inherits real stdio. Every step is idempotent.

```bash
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="$(hostname -s)"

# --- 1. Device-keyed internal symlinks ------------------------------
link_device_variant() {
  local dir="$1" target_link="$2" fallback="$3"
  local pick="$dir/${HOSTNAME}.conf"
  [[ -f "$pick" ]] || pick="$dir/${fallback}.conf"
  ln -sfn "$(basename "$(dirname "$pick")")/$(basename "$pick")" "$target_link"
}
link_device_variant "$MODULE_DIR/files/hypr/monitors"   "$MODULE_DIR/files/hypr/monitors.conf"  "default"
link_device_variant "$MODULE_DIR/files/voxtype/configs" "$MODULE_DIR/files/voxtype/config.toml" "default"

# --- 2. SDDM (sudo) -------------------------------------------------
if [[ "$(readlink /etc/sddm.conf 2>/dev/null)" != "$MODULE_DIR/files/sddm.conf" ]]; then
  sudo ln -sfn "$MODULE_DIR/files/sddm.conf" /etc/sddm.conf
fi

SDDM_THEME_DIR="/usr/share/sddm/themes/$(basename "$MODULE_DIR/files/sddm-theme")"
if ! sudo diff -rq "$MODULE_DIR/files/sddm-theme" "$SDDM_THEME_DIR" >/dev/null 2>&1; then
  sudo mkdir -p "$SDDM_THEME_DIR"
  sudo cp -rT "$MODULE_DIR/files/sddm-theme" "$SDDM_THEME_DIR"
fi

# --- 3. Voxtype interactive setup -----------------------------------
if command -v voxtype >/dev/null 2>&1; then
  voxtype setup --download
  sudo voxtype setup gpu --enable
  [[ -f "$HOME/.config/systemd/user/voxtype.service" ]] || voxtype setup systemd
  voxtype setup compositor hyprland
fi

# --- 4. Matugen first-run render ------------------------------------
if [[ ! -f "$HOME/.config/hypr/colors/matugen.conf" ]]; then
  matugen image "$MODULE_DIR/files/wallpapers/default.png"
fi
```

### Idempotency rules for `install.sh`

- Every block must be guarded by an explicit check (`[[ -L … ]]`, `readlink` compare, `diff -rq`, `command -v`, file-exists). Re-running `quill apply hyprland` produces no observable side effects when the system is already in the desired state.
- No reload commands (`hyprctl reload`, `pkill -SIGUSR2 waybar`, etc.). The runner doesn't reload running apps; that's the wallpaper-switch script's job.

## Execution flow

### Fresh install

1. **Runner builds plan** from `module.toml`. The pacman + AUR drivers opt into `NeedsSudo()`. Runner primes sudo (`sudo -v`) once, upfront.
2. **Declarative actions run inside the TUI** in canonical order: directories → packages (pacman, then AUR) → symlinks → files → commands → services. Per-action progress visible in the TUI.
3. After this step: packages installed, `~/.config/{hypr,waybar,swaync,kitty,matugen,voxtype,wallpapers}` symlinked into the module, `~/.config/cliphist/config` written, `bluetooth.service` and `sddm.service` enabled.
4. **TUI releases the terminal.** Real stdio returns.
5. **`install.sh` runs** with inherited TTY:
   - Internal device-keyed symlinks (`monitors.conf`, `voxtype/config.toml`).
   - SDDM `/etc` symlink and `/usr/share/sddm/themes/` deployment via sudo.
   - Voxtype's four setup commands.
   - One-time matugen render against the bundled default wallpaper.
6. Reboot or log out → SDDM picks up its theme → log in → Hyprland session is live with colors generated from the bundled default wallpaper.

### Re-apply

- All declarative actions return `Check() == true` and are skipped. TUI shows everything as up-to-date.
- `install.sh` runs again, but every block is gated. Net cost: a few `stat`/`diff` syscalls, no observable side effects.

### Theme switching at runtime

Entirely outside quill:

- A user-bound script (lives at e.g. `files/hypr/scripts/wallpaper-switch.sh`) calls `matugen image <new-wallpaper>`.
- Matugen regenerates color files in `~/.config/{hypr,waybar,kitty,gtk-3.0,gtk-4.0}/colors/` per its template/post-hook config.
- Post-hooks reload running apps (`hyprctl reload`, `pkill -SIGUSR2 waybar`, `kill -SIGUSR1 $(pidof kitty)`, `swaync-client --reload-config`).

Quill never re-runs matugen after first install.

## Migration steps

Captured here for the implementation plan to pick up — *not* part of this spec's design, but listed so they aren't forgotten:

1. Delete `modules/kitty/`. Its content folds into `modules/hyprland/files/kitty/`.
2. Update any `hosts/<hostname>.toml` that listed `kitty`: remove it from the modules list and add `hyprland` if not already present (the `hyprland` module now owns kitty).
3. Seed `modules/hyprland/files/{hypr,waybar,kitty,swaync,wallpapers,matugen}/` from the corresponding `~/.config/*_new/` directories.
4. Author `module.toml` and `install.sh` per the shapes above.
5. Add the two `.gitignore` entries.
6. Add a default wallpaper at `files/wallpapers/default.<ext>`.
7. Decommission `~/.dotfiles/arch/modules/hyprland/use-{new,primary}-config.sh` (no longer needed).

## Validation strategy

This module ships content + `install.sh`, not new Go code, so the test surface is light:

- **No new Go tests required.** Quill's existing `manifest/parse_test.go` already validates the schema we're using; no new action types means no new `_test.go` files in `internal/action/`.
- **Smoke test in the plan:** `./bin/quill apply hyprland` on a clean state, verify the symlinks and `install.sh` outputs, run a second time, verify everything is up-to-date in the TUI and `install.sh` produces no new side effects.
- **Idempotency check:** every `install.sh` block must be guarded; the spec states this as a hard rule.

## Decisions and rationale

### Why one mega-module instead of sub-modules?

The user explicitly wants this bundled. The apps share install ordering (waybar/swaync need Hyprland packages), share host-specific behavior, and aren't independently useful (kitty is themed by matugen alongside the rest). Splitting into `hyprland`, `waybar`, `swaync`, etc. would create cross-module dependencies that mirror the bundle's natural shape.

### Why `install.sh` for device-keyed internal symlinks instead of a new action type?

1. **The symlink target is inside the module, not in `$HOME`.** Quill's `[[symlinks]]` action is for "module file → user-facing path." The device-keyed pattern places a symlink at `files/hypr/monitors.conf` pointing at a sibling file in the same tree — that's intra-module organization, not a user-facing dotfile decision.
2. **Quill's per-action `hosts` filter could express the same thing using dst-traversal through the parent dir-symlink.** But that produces "spooky" behavior: the runner thinks it's creating a symlink at a user-facing path, but the on-disk symlink lives inside the repo. Confusing for future maintenance.
3. **Adding a new action type is a 5-step change** (schema, parser test, action with Check/Apply, runner wiring, docs) and demand is one module. YAGNI applies.
4. **Trade-off acknowledged:** `install.sh`-handled symlinks aren't visible in `quill status` and don't get individual Check/Apply progress in the TUI. Acceptable for two cases (`monitors`, `voxtype`).

If a future module wants the same pattern, we promote it to an action type.

### Why `install.sh` for matugen first-run instead of a `[[commands]]` action?

`matugen` produces TTY progress output and its check semantics (`is the colors file present?`) are simple bash. Could be a `[[commands]]` entry, but the same is true of every step in `install.sh`, and grouping all imperative work in one script keeps the boundary clear: declarative actions are quill's responsibility, `install.sh` is the module's escape hatch.

### Why is theme switching outside quill?

Matugen runs at runtime, driven by the user's wallpaper choice. Quill is install-time and stateless. Trying to express "the active theme" in quill would either require persisted state (anti-goal) or a re-render-on-every-apply (wasteful). Cleaner to make matugen integration one-directional: quill installs the binary and templates, matugen handles all subsequent renders independently.

### Why bundle a default wallpaper?

First-run matugen needs something to render against. The alternatives were "use the user's existing wallpaper" (won't exist on a fresh machine) or "skip first-run if no wallpaper" (apps fail to source files that don't exist yet). A committed default sidesteps both.

## Risks

- **AUR failure on fresh machine.** First-run matugen requires a working `matugen` binary, installed by AUR. If AUR is broken, `install.sh` fails at the matugen step. Mitigation: re-running `quill apply hyprland` after fixing AUR is safe; declarative steps no-op, install.sh's guards let it continue from where it failed.
- **SDDM theme is `cp`'d, not symlinked.** Editing theme assets in the repo doesn't propagate live; requires re-running `quill apply hyprland`. Acceptable for v1.
- **Voxtype `setup gpu --enable` requires sudo.** Runner's primed sudo cache should still be valid (`timestamp_timeout` defaults to 5 minutes). If aged out, voxtype prompts and the inherited TTY handles it.
