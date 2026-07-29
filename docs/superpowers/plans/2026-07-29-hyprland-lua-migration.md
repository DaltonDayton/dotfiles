# Hyprland Lua Config Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the hyprland module's Hyprland config from hyprlang `.conf` to Lua before Hyprland 0.57 drops hyprlang, including the theme engine's dual-format color pipeline.

**Architecture:** Mirror the current file split as Lua modules loaded from `hyprland.lua` via `require`. Colors flow through a Lua indirection file (`colors/colors.lua`) written by `apply-theme.sh`, backed by a new matugen Lua template and per-theme `hypr.lua` color tables. Hyprlock keeps the existing hyprlang color chain untouched.

**Tech Stack:** Hyprland 0.56 Lua config API (`hl.*`), bash (install.sh, apply-theme.sh), matugen templates, quill module system.

**Spec:** `docs/superpowers/specs/2026-07-29-hyprland-lua-migration-design.md`

## Global Constraints

- Atomic cutover: migrated `.conf` files are deleted in this branch; no dual-format Hyprland config.
- `hyprlock.conf`, `hypridle.conf`, `files/hypr/colors/*.conf` chain, themes' `hypr.conf`, and `files/matugen/templates/hyprland-colors.conf` stay hyprlang — never edit or delete them.
- All work happens in a git worktree (superpowers:using-git-worktrees). `~/.config/hypr` symlinks into the MAIN checkout, so the live session only sees the change at merge. Do not merge until Task 10's pre-merge gate passes.
- Every new `.lua` file must pass `luac -p <file>` (syntax parse) before commit.
- Lua files use 4-space indent, no comment banners; keep the short *why* comments carried over from the `.conf` files.
- Commit messages: Conventional Commits, `feat(hyprland): ...` / `chore(hyprland): ...`.
- Key syntax facts (verified against wiki, 2026-07-29): `hl.config({...})`, `hl.bind(keys, dispatcher, opts?)` with opts `repeating/locked/mouse/release/description`, `hl.dsp.exec_cmd/focus/submap/layout`, `hl.dsp.window.*` (`close`, `float`, `fullscreen`, `move`, `resize`, `drag`), `hl.dsp.workspace.toggle_special(name)`, `hl.define_submap(name, fn)`, `hl.dispatch(d)` inside function binds, `hl.env(k, v)`, `hl.on("hyprland.start", fn)` + `hl.exec_cmd`, `hl.monitor({...})`, `hl.workspace_rule({...})`, `hl.window_rule({match=...})`, `hl.layer_rule({match=...})`, `hl.curve(name, {type="bezier", points={{x0,y0},{x1,y1}}})`, `hl.animation({leaf=..., ...})`, `hl.device({name=..., ...})`, `hl.gesture({fingers=..., direction=..., action=...})`, `require("dir/file")` (slash paths, absolute paths allowed, isolated scopes, returns module value).

---

### Task 1: Matugen Lua color template

**Files:**
- Create: `modules/hyprland/files/matugen/templates/hyprland-colors.lua`
- Modify: `modules/hyprland/files/matugen/config.toml` (after the `[templates.hyprland]` block, lines 24-27)

**Interfaces:**
- Produces: matugen writes `~/.config/hypr/colors/matugen.lua`, a Lua module returning a table with keys `image, bg0..bg4, fg, red, orange, yellow, green, aqua, blue, purple, grey0, grey1, grey2` (string color values like `"rgb(1d2021)"`). Tasks 2, 7, 8 rely on exactly these keys.

- [ ] **Step 1: Create the template**

`modules/hyprland/files/matugen/templates/hyprland-colors.lua`:

```lua
return {
    image = [[{{image}}]],

    bg0 = "rgb({{palettes.neutral._5.hex_stripped}})",
    bg1 = "rgb({{palettes.neutral._10.hex_stripped}})",
    bg2 = "rgb({{palettes.neutral._15.hex_stripped}})",
    bg3 = "rgb({{palettes.neutral._20.hex_stripped}})",
    bg4 = "rgb({{palettes.neutral._25.hex_stripped}})",

    fg = "rgb({{colors.on_surface.default.hex_stripped}})",

    red    = "rgb({{colors.error.default.hex_stripped}})",
    orange = "rgb({{colors.tertiary.default.hex_stripped}})",
    yellow = "rgb({{colors.tertiary_fixed.default.hex_stripped}})",
    green  = "rgb({{colors.primary.default.hex_stripped}})",
    aqua   = "rgb({{colors.secondary_fixed.default.hex_stripped}})",
    blue   = "rgb({{colors.secondary.default.hex_stripped}})",
    purple = "rgb({{colors.primary_fixed.default.hex_stripped}})",

    grey0 = "rgb({{colors.outline_variant.default.hex_stripped}})",
    grey1 = "rgb({{colors.outline.default.hex_stripped}})",
    grey2 = "rgb({{colors.on_surface_variant.default.hex_stripped}})",
}
```

Before writing, diff the color-source expressions against `modules/hyprland/files/matugen/templates/hyprland-colors.conf` — every `$name = rgb(...)` line there must have a matching key here with the identical `{{...}}` expression. If the `.conf` template has vars not listed above, add them.

- [ ] **Step 2: Add the matugen template entry**

In `modules/hyprland/files/matugen/config.toml`, directly after the `[templates.hyprland]` block:

```toml
[templates.hyprland_lua]
input_path = '~/.config/matugen/templates/hyprland-colors.lua'
output_path = '~/.config/hypr/colors/matugen.lua'
```

No `post_hook` — the existing `[templates.hyprland]` block already runs `hyprctl reload` and matugen writes all templates before hooks fire.

- [ ] **Step 3: Verify syntax**

Run: `luac -p modules/hyprland/files/matugen/templates/hyprland-colors.lua`
Expected: no output, exit 0 (the `{{...}}` placeholders sit inside strings, so the file parses as-is).

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/matugen/templates/hyprland-colors.lua modules/hyprland/files/matugen/config.toml
git commit -m "feat(hyprland): add matugen lua color template for hyprland lua config"
```

---

### Task 2: Per-theme `hypr.lua` color tables (10 static themes)

**Files:**
- Create: `modules/hyprland/files/themes/<t>/hypr.lua` for `catppuccin e-ink everforest-dark gruvbox-dark kanagawa nightfox noir nord rose-pine tokyo-night` (skip `matugen` — it has no `hypr.conf`)

**Interfaces:**
- Produces: each `hypr.lua` returns a table with the same color keys as Task 1 minus `image` (`bg0..bg4, fg, red..purple, grey0..grey2`). Task 8's `apply-theme.sh` requires these files by absolute path.

- [ ] **Step 1: Generate with a conversion script**

Each `hypr.conf` contains only `$name = rgb(hex)` lines, blanks, and comments. Run from repo root:

```bash
for t in catppuccin e-ink everforest-dark gruvbox-dark kanagawa nightfox noir nord rose-pine tokyo-night; do
  f="modules/hyprland/files/themes/$t/hypr.conf"
  out="modules/hyprland/files/themes/$t/hypr.lua"
  { echo "return {"
    sed -nE 's/^\$([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$/    \1 = "\2",/p' "$f"
    echo "}"
  } > "$out"
  luac -p "$out"
done
```

- [ ] **Step 2: Verify completeness**

Run: `for t in catppuccin e-ink everforest-dark gruvbox-dark kanagawa nightfox noir nord rose-pine tokyo-night; do echo "$t: $(grep -c '=' modules/hyprland/files/themes/$t/hypr.lua) lua / $(grep -c '^\$' modules/hyprland/files/themes/$t/hypr.conf) conf"; done`
Expected: lua count = conf count for every theme. Spot-check `gruvbox-dark/hypr.lua` contains `blue = "rgb(458588)",`.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/themes/*/hypr.lua
git commit -m "feat(hyprland): add lua color tables to static themes"
```

---

### Task 3: `programs.lua` and `keybindings.lua`

**Files:**
- Create: `modules/hyprland/files/hypr/programs.lua`
- Create: `modules/hyprland/files/hypr/keybindings.lua`

**Interfaces:**
- Consumes: nothing (self-contained; `keybindings.lua` requires `programs`).
- Produces: `programs.lua` returns `{ terminal, fileManager, menu }`. `hyprland.lua` (Task 6) will `require("keybindings")` for side effects.

- [ ] **Step 1: Write `programs.lua`**

```lua
-- Programs used by keybindings.
return {
    terminal = "kitty",
    fileManager = "dolphin",
    menu = "rofi -show drun",
}
```

- [ ] **Step 2: Write `keybindings.lua`**

Full conversion of `keybindings.conf` (ignore the large commented-out legacy block at the bottom of the `.conf` — do not port it). Flag mapping: `binde` → `{ repeating = true }`, `bindl` → `{ locked = true }`, `bindel` → `{ locked = true, repeating = true }`, `bindm` → `{ mouse = true }`, `binded` → `{ description = "..." }`.

```lua
-- See https://wiki.hypr.land/Configuring/Basics/Binds/
local programs = require("programs")

local mod = "SUPER"
local browser = "firefox"

-- Application shortcuts
hl.bind(mod .. " + E", hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mod .. " + T", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mod .. " + F", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(programs.menu))

-- Window state
hl.bind(mod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + Return", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("systemctl --user start hyprlock-watch.service"))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("wlogout"))

-- Window navigation
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Move active window around current workspace (floating windows move by
-- coordinates, tiled windows swap in the direction).
local moveactive = 'grep -q "true" <<< $(hyprctl activewindow -j | jq -r .floating) && hyprctl dispatch moveactive'
hl.bind(mod .. " + SHIFT + left", hl.dsp.exec_cmd(moveactive .. " -30 0 || hyprctl dispatch movewindow l"), { description = "Move active window to the left" })
hl.bind(mod .. " + SHIFT + right", hl.dsp.exec_cmd(moveactive .. " 30 0 || hyprctl dispatch movewindow r"), { description = "Move active window to the right" })
hl.bind(mod .. " + SHIFT + up", hl.dsp.exec_cmd(moveactive .. " 0 -30 || hyprctl dispatch movewindow u"), { description = "Move active window up" })
hl.bind(mod .. " + SHIFT + down", hl.dsp.exec_cmd(moveactive .. " 0 30 || hyprctl dispatch movewindow d"), { description = "Move active window down" })

-- Resize windows
hl.bind(mod .. " + SHIFT + CTRL + Right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + CTRL + Left", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + CTRL + Up", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + CTRL + Down", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })

-- Move/resize windows with mouse drag
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Workspaces 1-10: switch, move, move silently
for i = 1, 10 do
    local key = tostring(i % 10) -- workspace 10 lives on the 0 key
    local ws = tostring(i)
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws, follow = true }))
    hl.bind(mod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

-- Relative workspaces
hl.bind(mod .. " + CTRL + ALT + Right", hl.dsp.window.move({ workspace = "r+1", follow = true }))
hl.bind(mod .. " + CTRL + ALT + Left", hl.dsp.window.move({ workspace = "r-1", follow = true }))
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + CTRL + Left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + CTRL + Down", hl.dsp.focus({ workspace = "empty" }))

-- Scratchpad
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = true }))

-- Scroll through workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Special workspace shortcuts
local specials = { M = "music", F = "files", T = "monitoring", O = "obsidian", B = "playwright" }
for key, name in pairs(specials) do
    hl.bind(mod .. " + ALT + " .. key, hl.dsp.workspace.toggle_special(name))
end
local special_moves = { M = "music", F = "files", T = "monitoring", O = "obsidian" }
for key, name in pairs(special_moves) do
    hl.bind(mod .. " + SHIFT + ALT + " .. key, hl.dsp.window.move({ workspace = "special:" .. name, follow = true }))
end

-- Multimedia (laptop volume/brightness keys)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Laptop lid switch: disable/enable built-in display
hl.bind("switch:on:Lid Switch", function()
    hl.monitor({ output = "eDP-1", mode = "disable" })
end, { locked = true })
hl.bind("switch:off:Lid Switch", function()
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })
end, { locked = true })

-- Media control (requires playerctl)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Screen capture (requires grimblast, satty, wf-recorder, slurp)
hl.bind(mod .. " + P", hl.dsp.exec_cmd([[grimblast --freeze copysave area /tmp/screenshot.png && satty --filename /tmp/screenshot.png --copy-command=wl-copy --actions-on-escape="save-to-clipboard,exit" --output-filename ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d-%H%M%S).png]]))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd([[grimblast copysave output /tmp/screenshot.png && satty --filename /tmp/screenshot.png --copy-command=wl-copy --actions-on-escape="save-to-clipboard,exit" --output-filename ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d-%H%M%S).png]]))
hl.bind(mod .. " + ALT + P", hl.dsp.exec_cmd([[grimblast copysave screen /tmp/screenshot.png && satty --filename /tmp/screenshot.png --copy-command=wl-copy --actions-on-escape="save-to-clipboard,exit" --output-filename ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d-%H%M%S).png]]))
hl.bind(mod .. " + G", hl.dsp.exec_cmd([[pkill -INT wf-recorder || (notify-send "GIF Recording" "Select region to record" -t 2000 && wf-recorder -g "$(slurp)" -c gif -r 10 -f ~/Videos/GIFs/recording-$(date +%Y%m%d-%H%M%S).gif && notify-send "GIF Recording" "Saved to ~/Videos/GIFs/")]]))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd([[pkill -INT wf-recorder || (notify-send "MP4 Recording" "Select region to record" -t 2000 && wf-recorder -g "$(slurp)" -f ~/Videos/Recordings/recording-$(date +%Y%m%d-%H%M%S).mp4 && notify-send "MP4 Recording" "Saved to ~/Videos/Recordings/")]]))
hl.bind(mod .. " + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/ocr-screenshot.sh"))

-- Theming
hl.bind(mod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/theme-switcher.sh"))
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-picker.sh"))

-- Panels and clipboard
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd([[cliphist wipe && wl-copy --clear && notify-send "Clipboard" "History cleared"]]))
hl.bind(mod .. " + U", hl.dsp.exec_cmd([[u=$(uuidgen) && printf %s "$u" | wl-copy && notify-send "UUID copied" "$u"]]))

-- Voice dictation (requires voxtype, wtype)
hl.bind(mod .. " + B", hl.dsp.exec_cmd("voxtype record toggle"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("voxtype record toggle --clipboard"))
```

- [ ] **Step 3: Verify syntax**

Run: `luac -p modules/hyprland/files/hypr/programs.lua modules/hyprland/files/hypr/keybindings.lua`
Expected: exit 0, no output.

- [ ] **Step 4: Count check against the source**

Run: `grep -cE '^(bind|binde|bindl|bindel|bindm|binded) ' modules/hyprland/files/hypr/keybindings.conf` and `grep -c 'hl.bind(' modules/hyprland/files/hypr/keybindings.lua`
Expected: `.lua` count matches `.conf` count once loop-generated binds are expanded (the two `for` loops produce 30 + 5 + 4 = 39 binds from 5 `hl.bind(` occurrences; do the arithmetic and confirm totals match; the `.conf` count includes only uncommented lines).

- [ ] **Step 5: Commit**

```bash
git add modules/hyprland/files/hypr/programs.lua modules/hyprland/files/hypr/keybindings.lua
git commit -m "feat(hyprland): convert keybindings and programs to lua"
```

---

### Task 4: `windowrules.lua`

**Files:**
- Create: `modules/hyprland/files/hypr/windowrules.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: side-effect module; `hyprland.lua` (Task 6) will `require("windowrules")`.

- [ ] **Step 1: Write `windowrules.lua`**

Full conversion of `windowrules.conf` (workspace rules, layer rules, window rules — carry over the *why* comments):

```lua
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Special workspaces
hl.workspace_rule({ workspace = "special:scratchpad", on_created_empty = "kitty", gaps_out = 40, gaps_in = 20 })
hl.workspace_rule({ workspace = "special:music", on_created_empty = "spotify", gaps_out = 20, gaps_in = 10 })
hl.workspace_rule({ workspace = "special:files", on_created_empty = "dolphin", gaps_out = 20, gaps_in = 10 })
hl.workspace_rule({ workspace = "special:monitoring", on_created_empty = "[float] kitty -e btop", gaps_out = 30, gaps_in = 15 })
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian", gaps_out = 25, gaps_in = 12 })
hl.workspace_rule({ workspace = "special:playwright", gaps_out = 20, gaps_in = 10 })

-- Layers
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.3 })

-- Windows
hl.window_rule({
    -- Ignore maximize requests from all apps.
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = { 20, "monitor_h-120" },
    float = true,
})

hl.window_rule({
    name = "world-of-warcraft",
    match = { title = "World of Warcraft" },
    idle_inhibit = "always",
    opacity = 1,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    render_unfocused = true, -- fixes game freezing when moving workspaces
    immediate = true,
    fullscreen = true,
    fullscreen_state = { internal = 2, client = 2 },
})

hl.window_rule({
    name = "zoo-tycoon",
    match = { title = "Zoo Tycoon" },
    idle_inhibit = "always",
    opacity = 1,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    fullscreen = true,
    fullscreen_state = { internal = 3 },
    render_unfocused = true, -- fixes game freezing when moving workspaces
    monitor = "DP-1", -- HYTE case monitor — not detected since 2026-07 reinstall; fix name when reconnected
})

hl.window_rule({
    name = "tradeskillmaster-float",
    match = { title = "TradeSkillMaster Application.*" },
    float = true,
    monitor = "DP-5", -- Samsung (bottom primary); port renumbered on 2026-07 reinstall
    workspace = "4",
    move = { 2831, 48 },
    size = { 600, 600 },
})

hl.window_rule({
    name = "TSMApplication",
    match = { title = "TSMApplication " },
    float = true,
    monitor = "DP-5", -- Samsung (bottom primary); port renumbered on 2026-07 reinstall
    workspace = "4",
    move = { 2831, 48 },
})

hl.window_rule({
    name = "battlenet-float",
    match = { title = "Battle.net" },
    float = true,
})

hl.window_rule({
    name = "devtools-windowed",
    match = { class = "firefox", initial_title = "^$" },
    float = true,
    size = { 1570, 970 },
})

hl.window_rule({
    -- Playwright / MCP automation launches headed Chromium; keep it a
    -- predictable floating window, parked silently on its own special
    -- workspace (mainMod+Alt+B to view) so it never disturbs the layout.
    name = "playwright-windowed",
    match = { class = "^chromium$" },
    float = true,
    size = { 1920, 1080 },
    center = true,
    workspace = "special:playwright silent",
})
```

Note: `fullscreen_state` table shapes are the best documented guess; Task 10 verifies via `hyprctl configerrors` — if rejected, fall back to string form `fullscreen_state = "2 2"` / `"3"`.

- [ ] **Step 2: Verify syntax**

Run: `luac -p modules/hyprland/files/hypr/windowrules.lua`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/hypr/windowrules.lua
git commit -m "feat(hyprland): convert window, workspace, and layer rules to lua"
```

---

### Task 5: Monitors per host + install.sh variant link

**Files:**
- Create: `modules/hyprland/files/hypr/monitors/archlinux.lua`, `modules/hyprland/files/hypr/monitors/archlaptop.lua`, `modules/hyprland/files/hypr/monitors/default.lua`
- Modify: `modules/hyprland/install.sh:17` (the monitors `link_device_variant` call)

**Interfaces:**
- Consumes: `link_device_variant(dir, target_link, fallback, ext)` already accepts an `ext` 4th arg (defaults `conf`).
- Produces: `monitors.lua` symlink → `monitors/<host>.lua`; `hyprland.lua` (Task 6) will `require("monitors")`.

- [ ] **Step 1: Write `monitors/archlinux.lua`**

```lua
-- Desktop — two ultrawide monitors (3440x1440), stacked vertically.
-- Matched by description, not port name: DP-N numbering shifted across the
-- 2026-07 reinstall (DP-2/DP-3 -> DP-4/DP-5) and desc survives that.

-- Top monitor — AOC, positioned above primary
hl.monitor({ output = "desc:AOC U34G2G4R3 0x000099D5", mode = "3440x1440@144", position = "0x-1440", scale = 1, vrr = 0 })

-- Bottom monitor (primary) — Samsung
hl.monitor({ output = "desc:Samsung Electric Company LC34G55T H1AK500000", mode = "3440x1440@165", position = "0x0", scale = 1, vrr = 0 })

-- HYTE Y70ti case monitor — right of bottom ultrawide, rotated 270 degrees.
-- Not detected since the reinstall; re-enable by desc once it shows up in
-- `hyprctl monitors all`.
-- hl.monitor({ output = "<desc>", mode = "3840x1100@60", position = "3440x0", scale = 1, transform = 3 })

-- Workspace-to-monitor assignments — Samsung is primary
hl.workspace_rule({ workspace = "1", monitor = "desc:Samsung Electric Company LC34G55T H1AK500000", default = true })
hl.workspace_rule({ workspace = "2", monitor = "desc:AOC U34G2G4R3 0x000099D5", default = true })
```

- [ ] **Step 2: Write `monitors/archlaptop.lua`**

```lua
-- Laptop — built-in display
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })

-- Laptop GPU workaround
hl.env("AQ_NO_MODIFIERS", "1")

-- Acer Z35P ultrawide
hl.monitor({ output = "desc:Acer Technologies Z35P T3ZAA0038511", mode = "3440x1440@50", position = "auto", scale = 1 })

-- Fallback — auto-detect any other connected monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
```

- [ ] **Step 3: Write `monitors/default.lua`**

```lua
-- Default fallback — auto-detect all connected monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
```

- [ ] **Step 4: Update install.sh**

Change line 17 from:

```bash
link_device_variant "$MODULE_DIR/files/hypr/monitors" "$MODULE_DIR/files/hypr/monitors.conf" "default"
```

to:

```bash
link_device_variant "$MODULE_DIR/files/hypr/monitors" "$MODULE_DIR/files/hypr/monitors.lua" "default" "lua"
```

- [ ] **Step 5: Verify**

Run: `luac -p modules/hyprland/files/hypr/monitors/*.lua && bash -n modules/hyprland/install.sh`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add modules/hyprland/files/hypr/monitors/*.lua modules/hyprland/install.sh
git commit -m "feat(hyprland): convert per-host monitor configs to lua"
```

---

### Task 6: Voxtype submaps + `hyprland.lua` entry point

**Files:**
- Create: `modules/hyprland/files/hypr/conf.d/voxtype-submap.lua`
- Create: `modules/hyprland/files/hypr/hyprland.lua`

**Interfaces:**
- Consumes: `colors/colors.lua` (runtime-generated, returns color table — may be absent on first boot), `keybindings.lua`, `windowrules.lua`, `monitors.lua` (Tasks 3-5).
- Produces: the active Hyprland config once merged. Submap names `voxtype_recording` / `voxtype_suppress` must stay exactly as-is (voxtype dispatches to them by name).

- [ ] **Step 1: Write `conf.d/voxtype-submap.lua`**

```lua
-- Voxtype compositor integration
-- Fixes modifier key interference when using compositor keybindings
-- Converted from: voxtype setup compositor hyprland
--
-- Two submaps are used:
-- - voxtype_recording: Active during recording/transcription. F12 cancels.
-- - voxtype_suppress: Active during text output. Blocks modifier keys.
--
-- NOTE: Do not bind Escape in voxtype_suppress. Binding Escape causes wtype's
-- first character to be dropped. See: https://github.com/hyprwm/Hyprland/issues/3165

local mod = "SUPER"

-- Recording submap - active during recording and transcription
hl.define_submap("voxtype_recording", function()
    hl.bind(mod .. " + B", function()
        hl.dispatch(hl.dsp.exec_cmd("voxtype record stop"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind(mod .. " + SHIFT + B", function()
        hl.dispatch(hl.dsp.exec_cmd("voxtype record toggle --clipboard"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind("F12", function()
        hl.dispatch(hl.dsp.exec_cmd("voxtype record cancel"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
end)

-- Output submap - blocks modifier keys during text output
hl.define_submap("voxtype_suppress", function()
    for _, key in ipairs({ "SUPER_L", "SUPER_R", "Control_L", "Control_R", "Alt_L", "Alt_R", "Shift_L", "Shift_R" }) do
        hl.bind(key, hl.dsp.exec_cmd("true"))
    end
    hl.bind("F12", hl.dsp.submap("reset")) -- emergency escape if voxtype crashes
end)
```

- [ ] **Step 2: Write `hyprland.lua`**

```lua
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/

-- Theme colors: colors/colors.lua is runtime-written by apply-theme.sh and
-- absent until the first theme switch; fall back to a neutral palette so a
-- fresh install still boots with sane borders.
local ok, colors = pcall(require, "colors/colors")
if not ok or type(colors) ~= "table" then
    colors = { blue = "rgb(458588)", bg4 = "rgb(665c54)" }
end

-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XDG_MENU_PREFIX", "arch-") -- File Extension Discovery (Requires: kbuildsycoca6 autostart)

-- NEEDED FOR NVIDIA
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Autostart
hl.on("hyprland.start", function()
    -- Activate the systemd graphical session so xdg-desktop-portal
    -- (Requisite=graphical-session.target) can start.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("waybar")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("swaync")
    hl.exec_cmd("solaar --window=hide")
    hl.exec_cmd("kbuildsycoca6") -- File Extension Discovery (Requires XDG_MENU_PREFIX env)
    hl.exec_cmd("systemctl --user start voxtype") -- Voice dictation daemon
    hl.exec_cmd("wl-paste --watch cliphist store") -- Clipboard history
    hl.exec_cmd("nm-applet --indicator")
end)

-- Look and feel
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        ["col.active_border"] = colors.blue,
        ["col.inactive_border"] = colors.bg4,
        resize_on_border = false,
        allow_tearing = false, -- see https://wiki.hypr.land/Configuring/Tearing/
        layout = "dwindle",
        no_focus_fallback = true,
    },
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },
    animations = { enabled = true },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification
        touchpad = {
            natural_scroll = true,
        },
    },
    cursor = {
        hide_on_key_press = true,
        inactive_timeout = 2,
    },
})

-- Animation curves, see https://wiki.hypr.land/Configuring/Animations/#curves
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, curve = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, curve = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, curve = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, curve = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, curve = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, curve = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, curve = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, curve = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, curve = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, curve = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, curve = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, curve = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, curve = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, curve = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, curve = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, curve = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, curve = "quick" })

-- Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Per-device input, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({ name = "logitech-usb-receiver-mouse", sensitivity = 0.0 })
hl.device({ name = "razer-razer-naga-v2-hyperspeed", sensitivity = 0.3 })

-- Split config modules
require("monitors") -- symlink -> monitors/<host>.lua
require("windowrules")
require("keybindings")
require("conf.d/voxtype-submap")
```

- [ ] **Step 3: Verify syntax**

Run: `luac -p modules/hyprland/files/hypr/hyprland.lua modules/hyprland/files/hypr/conf.d/voxtype-submap.lua`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/hypr/hyprland.lua modules/hyprland/files/hypr/conf.d/voxtype-submap.lua
git commit -m "feat(hyprland): add lua entry point and voxtype submaps"
```

---

### Task 7: Theme engine — `apply-theme.sh` dual write + gitignore

**Files:**
- Modify: `modules/hyprland/files/hypr/scripts/apply-theme.sh:118` (matugen branch) and `:142` (static branch)
- Modify: `modules/hyprland/files/.gitignore`

**Interfaces:**
- Consumes: Task 1's matugen output path `~/.config/hypr/colors/matugen.lua`; Task 2's `~/.config/themes/<t>/hypr.lua`.
- Produces: `~/.config/hypr/colors/colors.lua` returning the active color table; consumed by `hyprland.lua`'s `require("colors/colors")`.

- [ ] **Step 1: Add Lua indirection writes**

In the matugen branch, after the existing line

```bash
  write_one "$HOME/.config/hypr/colors/colors.conf"    'source = ~/.config/hypr/colors/matugen.conf'
```

add:

```bash
  write_one "$HOME/.config/hypr/colors/colors.lua"     'return require("colors/matugen")'
```

In the static branch, after

```bash
  write_one "$HOME/.config/hypr/colors/colors.conf"    "source = ~/.config/themes/${THEME}/hypr.conf"
```

add:

```bash
  write_one "$HOME/.config/hypr/colors/colors.lua"     "return require(\"$HOME/.config/themes/${THEME}/hypr.lua\")"
```

(The `.conf` writes stay — hyprlock still consumes that chain.)

- [ ] **Step 2: Gitignore the runtime Lua files**

Append to `modules/hyprland/files/.gitignore` (which already ignores `hypr/colors/colors.conf`):

```
hypr/colors/colors.lua
hypr/colors/matugen.lua
```

- [ ] **Step 3: Verify**

Run: `bash -n modules/hyprland/files/hypr/scripts/apply-theme.sh && git check-ignore modules/hyprland/files/hypr/colors/colors.lua`
Expected: both exit 0 (check-ignore prints the path).

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/apply-theme.sh modules/hyprland/files/.gitignore
git commit -m "feat(hyprland): theme engine writes lua color indirection"
```

---

### Task 8: Delete migrated hyprlang files

**Files:**
- Delete: `modules/hyprland/files/hypr/hyprland.conf`, `programs.conf`, `keybindings.conf`, `windowrules.conf`, `conf.d/voxtype-submap.conf`, `monitors/archlinux.conf`, `monitors/archlaptop.conf`, `monitors/default.conf`
- Delete (untracked symlink, if present in the worktree): `modules/hyprland/files/hypr/monitors.conf`

Keep: `hyprlock.conf`, `hypridle.conf`, everything under `files/themes/*/hypr.conf`, `files/matugen/templates/hyprland-colors.conf`.

- [ ] **Step 1: Remove files**

```bash
git rm modules/hyprland/files/hypr/hyprland.conf \
       modules/hyprland/files/hypr/programs.conf \
       modules/hyprland/files/hypr/keybindings.conf \
       modules/hyprland/files/hypr/windowrules.conf \
       modules/hyprland/files/hypr/conf.d/voxtype-submap.conf \
       modules/hyprland/files/hypr/monitors/archlinux.conf \
       modules/hyprland/files/hypr/monitors/archlaptop.conf \
       modules/hyprland/files/hypr/monitors/default.conf
rm -f modules/hyprland/files/hypr/monitors.conf
```

If `git rm` reports `monitors.conf` as tracked too, include it in the `git rm`.

- [ ] **Step 2: Confirm nothing references the deleted files**

Run: `grep -rn "programs.conf\|keybindings.conf\|windowrules.conf\|voxtype-submap.conf\|monitors.conf" modules/hyprland/ --include="*.sh" --include="*.toml" --include="*.lua"`
Expected: no hits (install.sh was updated in Task 5; `hyprland.conf` references inside comments of unrelated files are fine if any appear, judge each hit).

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(hyprland): drop hyprlang configs replaced by lua"
```

---

### Task 9: Docs touch-up

**Files:**
- Modify: `CLAUDE.md` (spec/plan table)

- [ ] **Step 1: Add the feature row**

In the `CLAUDE.md` "Specs and plans" table, add:

```markdown
| Hyprland Lua config migration (0.55+ `hl.*` API, dual-format colors) | `docs/superpowers/specs/2026-07-29-hyprland-lua-migration-design.md` | `docs/superpowers/plans/2026-07-29-hyprland-lua-migration.md` |
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: register hyprland lua migration spec and plan"
```

---

### Task 10: Merge cutover + live verification (requires the user at the desktop)

This task runs on the MAIN checkout after merge; the live session flips here. Coordinate with the user before starting — a broken config can drop the session to a black screen (rollback path below).

- [ ] **Step 1: Pre-merge gate (in the worktree)**

```bash
luac -p modules/hyprland/files/hypr/hyprland.lua \
        modules/hyprland/files/hypr/programs.lua \
        modules/hyprland/files/hypr/keybindings.lua \
        modules/hyprland/files/hypr/windowrules.lua \
        modules/hyprland/files/hypr/conf.d/voxtype-submap.lua \
        modules/hyprland/files/hypr/monitors/*.lua
bash -n modules/hyprland/install.sh modules/hyprland/files/hypr/scripts/apply-theme.sh
```

Expected: all exit 0. Also confirm `git status` in the worktree is clean and all 9 prior tasks are committed.

- [ ] **Step 2: Merge to main** (per superpowers:finishing-a-development-branch — ask the user first)

- [ ] **Step 3: Relink and seed (main checkout)**

```bash
cd ~/dotfiles && go build -o ./bin/quill ./cmd/quill && ./bin/quill apply hyprland
```

Expected: install.sh creates `files/hypr/monitors.lua -> monitors/archlinux.lua`. Verify: `readlink modules/hyprland/files/hypr/monitors.lua`.

Then seed the Lua color indirection before reloading Hyprland (matches the currently active theme):

```bash
~/.config/hypr/scripts/apply-theme.sh "$(cat ~/.local/state/themes/current)"
```

Expected: `~/.config/hypr/colors/colors.lua` exists; if the active theme is matugen, `~/.config/hypr/colors/matugen.lua` exists too.

- [ ] **Step 4: Reload and check for errors**

```bash
hyprctl reload && sleep 1 && hyprctl configerrors
```

Expected: `no errors`. If errors name specific keys, likely candidates and fallbacks:
- `col.active_border` rejected in table form → try `col_active_border` key.
- `fullscreen_state` table rejected → string form `"2 2"` / `"3"`.
- `gesture` action string rejected → check `hyprctl` output for valid actions, wiki Gestures page.
- `vrr` key rejected in `hl.monitor` → move to `hl.workspace_rule`/`misc` per current wiki.
Fix in repo, `hyprctl reload`, re-check. Commit fixes as `fix(hyprland): ...`.

- [ ] **Step 5: Functional spot checks (user drives)**

- SUPER+T opens kitty; SUPER+1..3 switch workspaces; SUPER+SHIFT+1 moves a window.
- SUPER+ALT+M toggles music special workspace.
- SUPER+B starts voxtype recording; SUPER+B again stops it (submap works).
- Launch a floating rule target (e.g. Battle.net or `chromium` for the playwright rule) if convenient.
- 3-finger horizontal swipe switches workspace (touchpad hosts).
- `hyprctl binds | grep -c bind` roughly matches the old bind count.

- [ ] **Step 6: Theme engine round-trip**

- SUPER+D → pick `gruvbox-dark`: border colors change; `cat ~/.config/hypr/colors/colors.lua` shows the absolute-path require of the theme's `hypr.lua`.
- SUPER+D → pick `matugen`, SUPER+SHIFT+D → pick a wallpaper: borders recolor; `~/.config/hypr/colors/matugen.lua` regenerated.
- Lock screen (SUPER+L): hyprlock renders with theme colors (proves the untouched hyprlang chain still works).

- [ ] **Step 7: Confirm the deprecation warning is gone**

Restart Hyprland (log out/in). The ".conf config format" warning must not appear.

- [ ] **Step 8: Laptop follow-up (async, next time the laptop pulls)**

`git pull && ./bin/quill apply hyprland` on archlaptop; verify `monitors.lua -> monitors/archlaptop.lua`, lid switch disable/enable works (the `hl.monitor` mode="disable" call in keybindings.lua — if it errors, fall back to `hl.dsp.exec_cmd("hyprctl keyword monitor \"eDP-1, disable\"")` if hyprctl keyword still exists, else wiki Monitors page for the disable form).

**Rollback (any failure that can't be fixed forward quickly):**

```bash
cd ~/dotfiles && git revert --no-edit <merge-commit> && ./bin/quill apply hyprland && hyprctl reload
```

Then restart Hyprland (lua→conf fallback requires a restart, not just reload).
