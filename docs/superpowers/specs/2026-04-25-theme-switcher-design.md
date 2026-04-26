# Theme Switcher — Design

> **Status (2026-04-26):** Mechanism implemented and shipping on `startover`. Two themes ship today (`rose-pine`, `matugen`); the other 9 meridian themes (`catppuccin`, `e-ink`, `everforest-dark`, `gruvbox-dark`, `kanagawa`, `nightfox`, `noir`, `nord-darker`, `tokyo-night`) are pending follow-up authoring work — see the "Status" section in the implementation plan.

## Context

The user has a working matugen-driven Material You theming pipeline in the `hyprland` module: matugen renders palettes from a wallpaper into `~/.config/<app>/colors/matugen.<ext>` for kitty / waybar / hyprland / GTK / rofi / pywalfox, with post-hooks reloading each app. There's also a parallel set of 10 hand-authored static palettes (catppuccin-mocha, gruvbox-dark, rose-pine, nord, kanagawa, tokyo-night, nightfox, e-ink, monochrome, everforest-dark) sitting in `modules/hyprland/files/waybar/colors/custom/*.css` — currently inert because nothing switches between them.

Inspiration came from `meridian` (a Hyprland environment under `~/Downloads/hypraccelerator/meridian`), which ships a bash-based theme switcher: per-theme bundles of color files, a rofi picker, an `apply-theme.sh` that copies files into place and reloads each app, plus per-theme wallpaper directories with last-used-wallpaper memory.

The user wants the meridian flow but with matugen treated as a first-class theme — selectable like any named theme, but with the wallpaper picker showing the union of every theme's wallpaper pool when matugen is active, and palette regeneration triggered on both theme-switch and wallpaper-change while matugen is the active theme.

## Goal

Two new keybindings:

- `Super+D` → rofi theme picker. Pick a theme → palette swaps across all 6 apps, wallpaper restores to whatever was last used in that theme, apps reload.
- `Super+Shift+D` → rofi wallpaper picker. Shows wallpapers belonging to the current theme. Pick one → wallpaper changes; if the current theme is matugen, palette regenerates from the new wallpaper.

The retired `walset` / `walset-backend` scripts (currently bound to `Super+D`) and their associated rofi flow get deleted.

The pipeline must:

1. Treat matugen as one theme among many — symmetric with static themes, with its own wallpaper-memory slot.
2. Source palettes from a per-theme bundle that ships in the repo.
3. Run via a single bulk symlink (`~/.config/themes` → `modules/hyprland/files/themes/`) plus per-app one-line indirection files. No per-theme palette installation step at quill-apply time.
4. Decouple matugen from the switcher: matugen's existing template output paths are unchanged; the switcher just rewrites the indirection to point at them when matugen is active.
5. Commit every palette (static and matugen) to a single canonical variable vocabulary so consumer configs (waybar `style.css`, kitty.conf, etc.) never need branching.

## Scope

**In scope (apps that get themed):** hypr, waybar, kitty, rofi, swaync, wlogout. (The "visible-shell" set — everything you actually see day-to-day on the Hyprland desktop.)

**Out of scope:**

- GTK theme name, VSCodium, Discord/vesktop, neovim, spicetify (no modules in the repo for those today).
- Light-mode variants. Every theme is dark; matugen mode is `dark`.
- Per-host theme overrides. Active theme is global to the user.
- Tests beyond manual smoke. The orchestration is bash; quill-side has no Go changes.
- A "force matugen on this image regardless of current theme" CLI. That was walset's job; it's gone. Switching to the matugen theme is the way.

## Repo layout

Theme assets live inside the existing `hyprland` module:

```
modules/hyprland/files/themes/
├── catppuccin-mocha/
│   ├── meta.toml             # display_name; reserved for future metadata
│   ├── hypr.conf             # $bg0/$fg/$red/... palette
│   ├── kitty.conf            # color0..color15 + background/foreground/cursor
│   ├── waybar.css            # @define-color bg0 ...; etc.
│   ├── rofi.rasi             # * { bg0:; fg:; ... } palette
│   ├── swaync.css            # @define-color bg0 ...; etc.
│   ├── wlogout.css           # @define-color bg0 ...; etc.
│   └── wallpapers/
│       ├── 01.jpg
│       └── 02.jpg
├── gruvbox-dark/             # same shape
├── rose-pine/
├── nord/
├── kanagawa/
├── tokyo-night/
├── nightfox/
├── everforest-dark/
├── e-ink/
├── monochrome/
└── matugen/
    ├── meta.toml             # mode = "matugen"
    └── wallpapers/           # matugen-curated images; pool also unions every other theme's wallpapers/
```

Bash scripts live in the existing hypr scripts subdir:

```
modules/hyprland/files/hypr/scripts/
├── theme-switcher.sh         # Super+D entry
├── wallpaper-picker.sh       # Super+Shift+D entry
└── apply-theme.sh            # called by theme-switcher and on first install
```

## Runtime layout (`~/.config`)

One symlink, plus six small mutable indirection files:

```
~/.config/themes  →  modules/hyprland/files/themes/    # planted by quill [[symlinks]]

~/.config/hypr/colors/colors.conf      # one line: source = ~/.config/themes/<active>/hypr.conf
~/.config/waybar/colors/colors.css     # one line: @import "../../themes/<active>/waybar.css";
~/.config/kitty/colors/colors.conf     # one line: include ~/.config/themes/<active>/kitty.conf
~/.config/rofi/colors/colors.rasi      # one line: @import "~/.config/themes/<active>/rofi.rasi"
~/.config/swaync/colors/colors.css     # one line: @import "...";
~/.config/wlogout/colors/colors.css    # one line: @import "...";
```

When `<active>` is `matugen`, each indirection points at `~/.config/<app>/colors/matugen.<ext>` instead — the files matugen's existing templates already write to. Matugen's `config.toml` is **unchanged**. The switcher just re-aims the indirection.

Each app's main config sources its respective `colors/colors.<ext>` exactly once. The current `include colors/matugen.conf` references in `kitty.conf`, `hyprland.conf`, etc. get changed to `colors/colors.conf` (one-line edits in 3 files; waybar layouts already use `colors/colors.css`).

## Switcher behavior

### `theme-switcher.sh` (Super+D)

1. List subdirectories of `~/.config/themes/` (excluding `.*`). Use `meta.toml`'s `display_name` for rofi labels if present, otherwise the dir name.
2. Show rofi picker with the current theme marked (e.g. `● catppuccin-mocha`). Read current theme from `${XDG_STATE_HOME:-$HOME/.local/state}/themes/current`.
3. On selection, call `apply-theme.sh <name>`.

### `apply-theme.sh <name>` (the workhorse)

1. **Resolve wallpaper.** Look up `<name>:<path>` in `${XDG_STATE_HOME:-$HOME/.local/state}/themes/wallpapers.txt`. If the path exists, that's the wallpaper. Otherwise pick the alphabetically-first wallpaper from the theme's pool:
   - matugen → union of every theme's `wallpapers/`
   - any other theme → just `themes/<name>/wallpapers/`
   Persist the choice back into `wallpapers.txt`.
2. **Rewrite the 6 indirection files** to point at the right palette source. For static themes: `~/.config/themes/<name>/<app>.<ext>`. For matugen: `~/.config/<app>/colors/matugen.<ext>`.
3. **Run the wallpaper / palette pipeline:**
   - **If matugen is the active theme:** `matugen image <wallpaper>`. Matugen's existing post-hooks rewrite the matugen palette files and reload each app. Done.
   - **If a static theme is active:** `awww img <wallpaper>` with the existing transition flags, then trigger app reloads explicitly:
     - `hyprctl reload`
     - `pkill -SIGUSR2 waybar`
     - `kill -SIGUSR1 $(pidof kitty)` (no-op if kitty not running)
     - `pkill swaync && swaync &` (swaync has no reload signal — must restart)
     - rofi: nothing (reads config per-launch)
     - wlogout: nothing (reads config per-launch)
4. **Persist active theme** to `${XDG_STATE_HOME:-$HOME/.local/state}/themes/current` (single line).
5. **Notify**: `notify-send "Theme" "<name>"`.

### `wallpaper-picker.sh` (Super+Shift+D)

1. Read current theme from `themes/current`.
2. Build wallpaper pool (matugen → union; otherwise → current theme's `wallpapers/`).
3. Show rofi picker with `-show-icons` (file path → thumbnail), current wallpaper marked.
4. On selection, persist `<theme>:<selected-path>` to `wallpapers.txt`.
5. Apply the wallpaper:
   - **If current theme is matugen:** `matugen image <selected-path>` (matugen post-hooks handle reload).
   - **If current theme is static:** `awww img <selected-path>` only — no palette regen, no app reloads.

### Invariants

- `apply-theme.sh` is the **only** writer of indirection files. Any future path that wants a theme change goes through it.
- Matugen runs **only** via the switcher (via theme-switcher with matugen active, or wallpaper-picker while matugen is active). Calling `matugen image X` from the shell still works mechanically (it'll regenerate the matugen palette files), but won't change the active theme — if the indirection currently points at static catppuccin, those regenerated matugen files just sit on disk unused.
- Lazy creation: `wallpapers.txt` and `current` are created on first run if absent. Default first-install theme is **rose-pine** (matches your current static look — preserves existing appearance).

## State

Two files under `${XDG_STATE_HOME:-$HOME/.local/state}/themes/`:

| File | Format | Written by |
|---|---|---|
| `current` | single line, theme name | `apply-theme.sh` |
| `wallpapers.txt` | `<theme>:<absolute-path>` lines, one per theme | `apply-theme.sh`, `wallpaper-picker.sh` |

Neither is checked into git. Both are read by both pickers.

## Quill module changes

All work lives inside the existing `modules/hyprland/` module. No new quill module, no new quill action types, no Go code.

### `module.toml`

Add one symlink and three new app config trees (rofi, swaync, wlogout — they're not currently in the module):

```toml
[[symlinks]]
src = "files/themes"
dst = "~/.config/themes"

[[symlinks]]
src = "files/rofi"
dst = "~/.config/rofi"

[[symlinks]]
src = "files/swaync"
dst = "~/.config/swaync"

[[symlinks]]
src = "files/wlogout"
dst = "~/.config/wlogout"
```

Add the three apps to `[[packages]]` (manager = "pacman") if not already present:

- `rofi` — already in the existing list
- `swaync`
- `wlogout`

(Verify against the current `module.toml` before editing.)

### `install.sh`

Add an idempotent indirection-seeding block that runs after the existing matugen first-run render. For each app, if the indirection file doesn't exist, write it pointing at rose-pine:

```bash
seed_indirection() {
  local target="$1" content="$2"
  if [[ ! -f "$target" ]]; then
    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$content" > "$target"
  fi
}

seed_indirection "$HOME/.config/hypr/colors/colors.conf"    'source = ~/.config/themes/rose-pine/hypr.conf'
seed_indirection "$HOME/.config/waybar/colors/colors.css"   '@import "../../themes/rose-pine/waybar.css";'
seed_indirection "$HOME/.config/kitty/colors/colors.conf"   'include ~/.config/themes/rose-pine/kitty.conf'
seed_indirection "$HOME/.config/rofi/colors/colors.rasi"    '@import "~/.config/themes/rose-pine/rofi.rasi"'
seed_indirection "$HOME/.config/swaync/colors/colors.css"   '@import "../../themes/rose-pine/swaync.css";'
seed_indirection "$HOME/.config/wlogout/colors/colors.css"  '@import "../../themes/rose-pine/wlogout.css";'
```

Also seed the state files so the first Super+D shows a sensible "current" mark:

```bash
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/themes"
[[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/themes/current" ]] || \
  echo rose-pine > "${XDG_STATE_HOME:-$HOME/.local/state}/themes/current"
```

The indirection files **cannot** be quill-managed `[[symlinks]]` (they're mutable; the switcher rewrites them) and shouldn't be `[[files]]` either (quill would enforce content equality and revert switcher changes on the next apply). The `install.sh` first-run seed pattern matches the existing matugen one.

### Files to delete

- `modules/hyprland/files/hypr/scripts/walset.sh`
- `modules/hyprland/files/hypr/scripts/walset-backend.sh`
- `modules/hyprland/files/waybar/colors/colors.css` (gets regenerated by `install.sh` seed)
- `modules/hyprland/files/waybar/colors/custom/*.css` (10 files — content moves into per-theme `themes/<name>/waybar.css`)
- The `Super+D, exec, ~/.local/bin/walset` line in `hyprland.conf`

### Files to add

- `modules/hyprland/files/themes/<theme>/{meta.toml,hypr.conf,kitty.conf,waybar.css,rofi.rasi,swaync.css,wlogout.css}` × 10 themes — 70 small palette files. The 10 `waybar.css` files are migrations of the existing `colors/custom/*.css`; the other 60 are new authoring work (mechanical translation of the same palette into 5 different syntaxes).
- `modules/hyprland/files/themes/<theme>/wallpapers/*.{jpg,png}` — at least one wallpaper per theme.
- `modules/hyprland/files/themes/matugen/{meta.toml,wallpapers/}`.
- `modules/hyprland/files/hypr/scripts/{theme-switcher.sh,wallpaper-picker.sh,apply-theme.sh}` (chmod +x).
- `modules/hyprland/files/rofi/`, `modules/hyprland/files/swaync/`, `modules/hyprland/files/wlogout/` — minimal main configs for each, each importing `colors/colors.<ext>`. Specific config content (theme styling beyond colors) is up to the user; the spec only requires the colors-import line.

### Hyprland binds (`hyprland.conf`)

```
# remove
bind = $mainMod, D, exec, ~/.local/bin/walset

# add
bind = $mainMod, D, exec, ~/.config/hypr/scripts/theme-switcher.sh
bind = $mainMod SHIFT, D, exec, ~/.config/hypr/scripts/wallpaper-picker.sh
```

### Existing matugen pipeline

Invocation pattern unchanged: the switcher and wallpaper-picker call `matugen image <wallpaper>`, matugen renders templates and runs post-hooks to reload affected apps. Two changes are needed in this work:

1. **All existing templates get rewritten** to emit the canonical variable vocabulary (covered below in "Matugen template rewrites"). They keep emitting Material names alongside as a free hedge.
2. **`matugen/config.toml` gains two new template sections** (swaync, wlogout) to cover the apps newly in scope, and the existing `[templates.rofi]` `output_path` changes from `~/.config/rofi/launchers/shared/matugen.rasi` to `~/.config/rofi/colors/matugen.rasi` so the indirection from `colors/colors.rasi` resolves correctly.

The matugen palette files at `~/.config/<app>/colors/matugen.<ext>` keep being matugen's output; the only difference post-this-work is that those files are *referenced* by an indirection rather than being directly sourced from each app's main config.

### Main app config edits (one line each)

- `modules/hyprland/files/kitty/kitty.conf`: `include colors/matugen.conf` → `include colors/colors.conf`
- `modules/hyprland/files/hypr/hyprland.conf`: `source = ~/.config/hypr/colors/matugen.conf` → `source = ~/.config/hypr/colors/colors.conf`
- `modules/hyprland/files/waybar/style.css` (the initial default before the waybar layout switcher overrides `~/.config/waybar/style.css` with a layout-specific symlink): change `@import 'colors/matugen.css';` → `@import 'colors/colors.css';` for consistency with the layouts.
- waybar layouts under `files/waybar/layouts/*/style.css` already do `@import "colors/colors.css";` — no change needed; the file's content changes role but the import path doesn't.
- rofi / swaync / wlogout main configs: ship pre-wired to `@import "colors/colors.<ext>"` (these are new files in this work).

## Variable vocabulary

Every palette file (static and matugen) commits to one canonical variable scheme — the existing terminal-color vocabulary already used in the static waybar palettes:

| Var | Role |
|---|---|
| `bg0` | base background |
| `bg1` | mantle / one step up |
| `bg2` | surface |
| `bg3` | elevated surface |
| `bg4` | overlay / divider |
| `fg` | primary foreground |
| `red` `orange` `yellow` `green` `aqua` `blue` `purple` | accent colors |
| `grey0` `grey1` `grey2` | muted text gradient |

Per-app syntax:

- hypr: `$bg0 = rgb(11111b)`
- waybar / swaync / wlogout: `@define-color bg0 #11111b;`
- rofi: `* { bg0: #11111b; ... }`
- kitty: `color0..color15` + `background` / `foreground` / `cursor` (kitty has its own keys; map terminal-color → ANSI16: `color0=bg0`, `color1=red`, `color2=green`, `color3=yellow`, `color4=blue`, `color5=purple`, `color6=aqua`, `color7=fg`, `color8..15` = bright variants)

Static themes already speak this scheme (the 10 existing waybar `custom/*.css` files are the reference). Hand-authoring the 50 new palette files is mechanical — same hex values, different syntax per app.

### Matugen template rewrites

The existing `modules/hyprland/files/matugen/templates/*.{conf,css,rasi}` emit Material You names (`$primary`, `@on_surface`, etc.). They get rewritten to emit the canonical scheme by mapping Material → terminal:

| Canonical | Material source |
|---|---|
| `bg0` | `surface` |
| `bg1` | `surface_container_low` |
| `bg2` | `surface_container` |
| `bg3` | `surface_container_high` |
| `bg4` | `surface_container_highest` |
| `fg` | `on_surface` |
| `grey0` | `outline_variant` |
| `grey1` | `outline` |
| `grey2` | `on_surface_variant` |
| `red` | `error` |
| `orange` | `tertiary` |
| `yellow` | `secondary_fixed_dim` |
| `green` | `primary` |
| `aqua` | `tertiary_container` |
| `blue` | `secondary` |
| `purple` | `inverse_primary` |

The mapping is inherently lossy — Material has 3 accent slots (primary/secondary/tertiary), terminal-color has 7. Matugen-mode "green" doesn't mean *the color green* — it means "the slot historically occupied by green," filled with whatever Material's `primary` happens to be. On a forest wallpaper that *will* be green; on a sunset wallpaper it'll be orange. That's expected — matugen mode is wallpaper-driven.

The matugen templates also keep emitting Material names alongside the canonical names (cheap — already generated). Any future config that wants raw Material can use them. Nothing in this spec depends on it.

### kitty mapping detail

Kitty's `kitty.conf` references `color0..color15`, `background`, `foreground`, `cursor`. The per-theme `kitty.conf` palette uses kitty's own keys, populated from the canonical 16-color set:

```
background  bg0
foreground  fg
cursor      fg
color0      bg0     color8   grey0
color1      red     color9   red       # bright = same accent (could brighten)
color2      green   color10  green
color3      yellow  color11  yellow
color4      blue    color12  blue
color5      purple  color13  purple
color6      aqua    color14  aqua
color7      fg      color15  fg
```

(Themes can override individual entries if they want richer dim/bright distinction — e.g. catppuccin sets distinct `color8..color15`. The above is the floor.)

## Migration plan (per theme, mechanical)

1. Move existing `waybar/colors/custom/<theme>.css` → `themes/<theme>/waybar.css`. No content change.
2. Hand-author `themes/<theme>/{hypr.conf,kitty.conf,rofi.rasi,swaync.css,wlogout.css}` from the same palette. Repetitive but mechanical — same hex values, different syntax.
3. Drop a few wallpapers into `themes/<theme>/wallpapers/`.
4. Write `themes/<theme>/meta.toml` with `display_name = "..."`.

10 themes × (5 new palette files + meta.toml) = 60 small new files. Scriptable with a generator if it gets tedious; one-by-one is fine for 10 themes.

## Validation

After the module changes land, smoke-test by hand:

1. `quill apply hyprland` on a fresh-ish state → verify the symlink + indirection seeds appear, no errors.
2. `Super+D` → see all 10 themes + matugen, current marked. Pick gruvbox-dark → wallpaper changes, all 6 apps re-color to gruvbox.
3. `Super+Shift+D` → see only gruvbox wallpapers. Pick a different one → wallpaper changes, no palette regen.
4. `Super+D` → matugen → wallpaper picker shows union pool, palette regenerates (matugen runs).
5. `Super+Shift+D` while on matugen → pick another wallpaper → matugen re-runs, palette regenerates.
6. `Super+D` → catppuccin-mocha → wallpaper restores to whatever catppuccin had last (or default). Palette swaps to catppuccin.
7. `quill apply hyprland` again → no churn, no spurious file rewrites.

If a consumer config references a variable not in the canonical set, that app shows wrong/missing colors after a theme switch. Fix the consumer config, not the palette.

## Out of scope (recap)

- GTK / VSCodium / Discord / nvim / spicetify theming
- Light-mode variants
- Per-host theme overrides
- Automated tests of the bash orchestration
- A "force matugen on this image regardless of theme" CLI (walset is gone; switching to matugen theme is the way)
- Any quill Go-code changes

## Future extensibility

Adding a new app to scope later (e.g. GTK):

1. Add `themes/<theme>/<app>.<ext>` per theme.
2. Add a matugen template for the app to `matugen/templates/`.
3. Add the app's indirection file to the seed list in `install.sh`.
4. Add `<app>/colors/colors.<ext>` reload step to `apply-theme.sh`.
5. Wire the app's main config to `@import` / `include` the indirection.

Adding a new theme later: drop a directory under `themes/`, populate the palette files and wallpapers. No quill apply needed — the bulk symlink picks it up immediately.
