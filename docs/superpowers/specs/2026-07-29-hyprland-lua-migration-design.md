# Hyprland Lua config migration — design

Date: 2026-07-29
Status: draft, pending review

## Why

Hyprland 0.55 replaced hyprlang (`.conf`) with Lua as the config language. We run
0.56.1, which warns: ".conf config format, support for which will be removed in
Hyprland 0.57." New config features are already Lua-only. Hyprlock, Hypridle,
and Hyprpaper keep hyprlang permanently (official announcement).

Sources: [Lua-ification announcement](https://hypr.land/news/26_lua/),
[wiki Start page](https://wiki.hypr.land/Configuring/Start/).

## Decisions (made during brainstorming)

- **Atomic cutover.** One branch converts everything, deletes migrated `.conf`
  files, switches the theme engine. Rollback is `git revert` + `quill apply` +
  Hyprland restart (lua-to-conf fallback needs a restart, not just reload).
- **Mirror the current file split.** Same mental map, smallest diff.
- **Hand rewrite.** ~500 lines to convert; community converters would still
  need a full review pass, and the theme-engine work is manual regardless.
- **Dual-format colors.** Hyprlock sources `colors/colors.conf` and uses
  `$fg`/`$bg0`/`$yellow`, and hyprlock stays hyprlang. The color pipeline must
  therefore emit hyprlang for hyprlock *and* Lua for Hyprland.

## Scope

### Migrates to Lua (then `.conf` deleted)

| Current | New | Notes |
|---|---|---|
| `hyprland.conf` | `hyprland.lua` | entry point, `require`s the rest |
| `programs.conf` | `programs.lua` | returns a table (`terminal`, `fileManager`, `menu`) |
| `keybindings.conf` | `keybindings.lua` | 98 binds, `hl.bind(keys, hl.dsp.*)` |
| `windowrules.conf` | `windowrules.lua` | `hl.window_rule({ match = ... })` |
| `monitors.conf` + `monitors/*.conf` | `monitors.lua` + `monitors/*.lua` | per-host symlink kept, `hl.monitor({})` |
| `conf.d/voxtype-submap.conf` | `conf.d/voxtype-submap.lua` | `hl.define_submap(name, fn)` |

### Stays hyprlang (untouched)

- `hyprlock.conf`, `hypridle.conf` — their tools keep hyprlang.
- `colors/colors.conf` + `colors/matugen.conf` — still generated, consumed by
  hyprlock only after migration.
- Themes' existing `hypr.conf` files — consumed by hyprlock's color chain.

### New files

- `colors/colors.lua` + `colors/matugen.lua` — Lua siblings of the color
  indirection (gitignored like their `.conf` siblings; runtime-generated).
- `files/matugen/templates/hyprland-colors.lua` — second matugen template
  emitting `return { blue = "rgb(...)", ... }`.
- `themes/<name>/hypr.lua` for the 10 static themes — Lua color table
  alongside the kept `hypr.conf`.

## Architecture

### Entry point and module graph

`hyprland.lua` mirrors today's `source =` graph with `require`:

```lua
local colors = require("colors.colors")   -- returns color table
local programs = require("programs")

hl.env("XCURSOR_SIZE", "24")
-- exec-once list, hl.config({ general = ..., decoration = ..., ... }),
-- animations, input, devices, gesture

require("monitors")        -- symlink -> monitors/<host>.lua
require("windowrules")
require("keybindings")
require("conf.d.voxtype-submap")
```

`programs.lua` returns `{ terminal = "kitty", fileManager = "dolphin", menu = "rofi -show drun" }`;
`keybindings.lua` requires it instead of hyprlang `$terminal` variables.

Hyprlang `$blue`-style color variables become table fields: `colors.blue`.

### Color pipeline (dual format)

```
matugen image <wallpaper>
  ├─ template hyprland-colors.conf → ~/.config/hypr/colors/matugen.conf   (hyprlock chain, unchanged)
  └─ template hyprland-colors.lua  → ~/.config/hypr/colors/matugen.lua    (NEW, Hyprland chain)

apply-theme.sh (matugen mode) writes:
  colors/colors.conf: source = ~/.config/hypr/colors/matugen.conf         (unchanged)
  colors/colors.lua:  return require("colors.matugen")                    (NEW)

apply-theme.sh (static mode) writes:
  colors/colors.conf: source = ~/.config/themes/<t>/hypr.conf             (unchanged)
  colors/colors.lua:  return require("/home/.../themes/<t>/hypr.lua")     (NEW, absolute-path require)
```

`hyprctl reload` hooks stay as they are.

### Quill / module wiring

- `module.toml`: no change; whole-directory symlinks (`files/hypr` →
  `~/.config/hypr`) are rename-transparent.
- `install.sh`: `link_device_variant .../monitors .../monitors.conf default`
  switches to `.../monitors.lua`; the `monitors.conf` symlink is removed with
  the cutover.
- `.gitignore`: add `colors/colors.lua`, `colors/matugen.lua` next to the
  existing `.conf` entries.
- First-boot seeding: whatever seeds `colors/colors.conf` today must also seed
  `colors.lua` (verify mechanism during implementation; likely apply-theme.sh
  or a default in install.sh).

## Details pinned during implementation (verified against wiki + `hyprctl configerrors`)

- Exact `hl.config` key shape for `col.active_border` / `col.inactive_border`.
- Lua API for `exec-once` and `gesture` (0.56 added Lua gestures).
- Whether `require` of a config-relative module returns the module's return
  value under Hyprland's isolated-scope require (wiki implies yes; if not,
  fall back to `dofile`).
- `animations`: `hl.animation({ leaf = ..., ... })` per row + bezier curve API.

None of these change the architecture; they are syntax lookups.

## Testing / verification

Live on the desktop (archlinux host), branch checked out:

1. `./bin/quill apply hyprland` (symlinks unchanged, sanity check).
2. `hyprctl reload`, then `hyprctl configerrors` must be clean.
3. Exercise: a few keybinds, submap (voxtype), window rules (pick 2-3
   observable ones), monitor layout correct.
4. Theme switch both directions: a static theme (e.g. gruvbox-dark) and the
   matugen theme with a wallpaper change. Confirm Hyprland border colors
   update *and* hyprlock still renders themed colors.
5. Laptop (archlaptop) flips on its next `git pull` + `quill apply`; monitors
   variant symlink must resolve to `monitors/archlaptop.lua`.

Rollback: `git revert`, `quill apply hyprland`, restart Hyprland.

## Out of scope

- Migrating hyprlock/hypridle (their tools keep hyprlang).
- Config restructure beyond the format change.
- Using Lua helpers (timers, events, callbacks) for new behavior.
- Waybar/kitty/rofi/swaync/wlogout theming (non-hyprlang formats, unaffected).
