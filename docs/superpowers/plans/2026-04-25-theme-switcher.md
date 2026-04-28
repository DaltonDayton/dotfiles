# Theme Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a rofi-driven theme switcher (Super+D) and per-theme wallpaper picker (Super+Shift+D) to the hyprland module. Matugen becomes one theme among many; static themes ship pre-baked palettes; an indirection layer per app keeps the switcher mechanism trivial.

**Architecture:** Per-theme bundles live at `modules/hyprland/files/themes/<name>/`. Quill plants one symlink (`~/.config/themes`). Each app has a one-line indirection file at `~/.config/<app>/colors/colors.<ext>` that the switcher rewrites to point at either the per-theme bundle (static) or matugen's existing output paths (matugen mode). All palettes commit to a single canonical variable vocabulary (`bg0/fg/red/...`).

**Tech Stack:** bash (orchestration), rofi (UI), matugen (Material You generator, unchanged), awww (wallpaper engine), hyprctl/pkill signals (reloads). No Go changes.

**Spec:** [`docs/superpowers/specs/2026-04-25-theme-switcher-design.md`](../specs/2026-04-25-theme-switcher-design.md)

---

## Status (2026-04-26)

All 30 tasks below are **complete and committed on `startover`**. The switcher mechanism, indirection layer, both pickers, the canonical-vocabulary matugen templates, and the install-time seeding all work. The current repo ships 11 theme bundles total (10 static + 1 matugen):

- Static: `catppuccin`, `e-ink`, `everforest-dark`, `gruvbox-dark`, `kanagawa`, `nightfox`, `noir`, `nord-darker`, `rose-pine`, `tokyo-night`
- Dynamic: `matugen` (`meta.toml` marker; palette is generated from the active wallpaper)

The earlier "remaining themes" follow-up from this plan has been completed in-repo.

Post-plan UX follow-ups landed on `startover`:

- `wallpaper-picker.sh` now supports an optional personal pool in matugen mode (`${MATUGEN_WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers}`).
- Wallpaper picker visuals moved to a dedicated rofi theme (`modules/hyprland/files/rofi/wallpaper-picker.rasi`).
- Thumbnail rendering is delegated to `rofi-thumbnail.sh` via `rofi -preview-cmd` for fixed-aspect image cards.

---

## File Structure

**New files:**
```
modules/hyprland/files/themes/
├── rose-pine/                            # reference static theme (full palette)
│   ├── meta.toml
│   ├── hypr.conf
│   ├── kitty.conf
│   ├── waybar.css                        # migrated from colors/custom/rose-pine.css
│   ├── rofi.rasi
│   ├── swaync.css
│   ├── wlogout.css
│   └── wallpapers/
│       └── (at least one image)
└── matugen/
    ├── meta.toml
    └── wallpapers/
        └── (at least one image)
modules/hyprland/files/hypr/scripts/
├── apply-theme.sh                        # workhorse, called by switcher and pickers
├── theme-switcher.sh                     # Super+D
├── wallpaper-picker.sh                   # Super+Shift+D
└── rofi-thumbnail.sh                     # preview-cmd thumbnail generator
modules/hyprland/files/rofi/
├── config.rasi
├── wallpaper-picker.rasi
└── colors/
    └── .gitkeep
modules/hyprland/files/swaync/
└── (minimal config dir importing colors/colors.css)
modules/hyprland/files/wlogout/
└── (minimal config dir importing colors/colors.css)
modules/hyprland/files/matugen/templates/
├── swaync-colors.css                     # NEW — matugen template
└── wlogout-colors.css                    # NEW — matugen template
```

**Modified files:**
```
modules/hyprland/module.toml              # add 4 [[symlinks]] + 2 packages
modules/hyprland/install.sh               # add seed_indirection block
modules/hyprland/files/hypr/hyprland.conf # source line + bind changes
modules/hyprland/files/kitty/kitty.conf   # include line change
modules/hyprland/files/waybar/style.css   # @import change
modules/hyprland/files/matugen/config.toml  # add swaync/wlogout sections; fix rofi path
modules/hyprland/files/matugen/templates/colors.css           # rewrite to canonical vocab
modules/hyprland/files/matugen/templates/hyprland-colors.conf # rewrite to canonical vocab
modules/hyprland/files/matugen/templates/kitty-colors.conf    # rewrite to canonical vocab
modules/hyprland/files/matugen/templates/rofi-colors.rasi     # rewrite to canonical vocab
```

**Deleted files:**
```
modules/hyprland/files/hypr/scripts/walset.sh
modules/hyprland/files/hypr/scripts/walset-backend.sh
modules/hyprland/files/waybar/colors/colors.css           # replaced by install.sh seed
modules/hyprland/files/waybar/colors/custom/*.css         # 10 files; rose-pine.css moves into themes/rose-pine/waybar.css, others deleted
```

Static theme authoring noted above has already landed; keep this plan as historical implementation detail.

---

## Task 1: Create the rose-pine theme bundle directory + meta.toml

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/meta.toml`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p modules/hyprland/files/themes/rose-pine/wallpapers
```

- [ ] **Step 2: Write the meta.toml**

```toml
display_name = "Rose Pine"
```

Path: `modules/hyprland/files/themes/rose-pine/meta.toml`

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/
git commit -m "themes: scaffold rose-pine bundle"
```

---

## Task 2: Migrate the existing rose-pine waybar palette

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/waybar.css`

- [ ] **Step 1: Move the existing palette**

```bash
git mv modules/hyprland/files/waybar/colors/custom/rose-pine.css \
       modules/hyprland/files/themes/rose-pine/waybar.css
```

- [ ] **Step 2: Verify content**

Run: `cat modules/hyprland/files/themes/rose-pine/waybar.css`

Expected: 19 `@define-color` lines (bg0..bg4, fg, red/orange/yellow/green/aqua/blue/purple, grey0/grey1/grey2). No content edits — the palette is already canonical.

- [ ] **Step 3: Commit**

```bash
git commit -m "themes: rose-pine — move waybar palette into bundle"
```

---

## Task 3: Author rose-pine hypr.conf palette

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/hypr.conf`

- [ ] **Step 1: Write the palette**

Path: `modules/hyprland/files/themes/rose-pine/hypr.conf`

```
$bg0 = rgb(191724)
$bg1 = rgb(1f1d2e)
$bg2 = rgb(26233a)
$bg3 = rgb(2a273f)
$bg4 = rgb(332e4e)

$red    = rgb(eb6f92)
$orange = rgb(f6c177)
$yellow = rgb(f6c177)
$green  = rgb(9ccfd8)
$aqua   = rgb(31748f)
$blue   = rgb(569fba)
$purple = rgb(c4a7e7)

$fg = rgb(e0def4)

$grey0 = rgb(6e6a86)
$grey1 = rgb(908caa)
$grey2 = rgb(e0def4)
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/hypr.conf
git commit -m "themes: rose-pine — hypr palette"
```

---

## Task 4: Author rose-pine kitty.conf palette

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/kitty.conf`

- [ ] **Step 1: Write the palette**

Path: `modules/hyprland/files/themes/rose-pine/kitty.conf`

```
background  #191724
foreground  #e0def4
cursor      #e0def4

color0  #191724
color1  #eb6f92
color2  #9ccfd8
color3  #f6c177
color4  #569fba
color5  #c4a7e7
color6  #31748f
color7  #e0def4

color8  #6e6a86
color9  #eb6f92
color10 #9ccfd8
color11 #f6c177
color12 #569fba
color13 #c4a7e7
color14 #31748f
color15 #e0def4
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/kitty.conf
git commit -m "themes: rose-pine — kitty palette"
```

---

## Task 5: Author rose-pine rofi.rasi palette

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/rofi.rasi`

- [ ] **Step 1: Write the palette**

Path: `modules/hyprland/files/themes/rose-pine/rofi.rasi`

```
* {
    bg0:    #191724;
    bg1:    #1f1d2e;
    bg2:    #26233a;
    bg3:    #2a273f;
    bg4:    #332e4e;

    fg:     #e0def4;

    red:    #eb6f92;
    orange: #f6c177;
    yellow: #f6c177;
    green:  #9ccfd8;
    aqua:   #31748f;
    blue:   #569fba;
    purple: #c4a7e7;

    grey0:  #6e6a86;
    grey1:  #908caa;
    grey2:  #e0def4;
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/rofi.rasi
git commit -m "themes: rose-pine — rofi palette"
```

---

## Task 6: Author rose-pine swaync.css palette

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/swaync.css`

- [ ] **Step 1: Write the palette**

Path: `modules/hyprland/files/themes/rose-pine/swaync.css`

```css
@define-color bg0 #191724;
@define-color bg1 #1f1d2e;
@define-color bg2 #26233a;
@define-color bg3 #2a273f;
@define-color bg4 #332e4e;

@define-color fg #e0def4;

@define-color red    #eb6f92;
@define-color orange #f6c177;
@define-color yellow #f6c177;
@define-color green  #9ccfd8;
@define-color aqua   #31748f;
@define-color blue   #569fba;
@define-color purple #c4a7e7;

@define-color grey0 #6e6a86;
@define-color grey1 #908caa;
@define-color grey2 #e0def4;
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/swaync.css
git commit -m "themes: rose-pine — swaync palette"
```

---

## Task 7: Author rose-pine wlogout.css palette

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/wlogout.css`

- [ ] **Step 1: Write the palette**

Path: `modules/hyprland/files/themes/rose-pine/wlogout.css`

```css
@define-color bg0 #191724;
@define-color bg1 #1f1d2e;
@define-color bg2 #26233a;
@define-color bg3 #2a273f;
@define-color bg4 #332e4e;

@define-color fg #e0def4;

@define-color red    #eb6f92;
@define-color orange #f6c177;
@define-color yellow #f6c177;
@define-color green  #9ccfd8;
@define-color aqua   #31748f;
@define-color blue   #569fba;
@define-color purple #c4a7e7;

@define-color grey0 #6e6a86;
@define-color grey1 #908caa;
@define-color grey2 #e0def4;
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/wlogout.css
git commit -m "themes: rose-pine — wlogout palette"
```

---

## Task 8: Add a wallpaper to the rose-pine bundle

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/wallpapers/default.jpg` (or any image)

- [ ] **Step 1: Drop a wallpaper in**

Use any image you like — at least one is required. If you don't have one handy, copy the existing default:

```bash
cp modules/hyprland/files/wallpapers/default.png \
   modules/hyprland/files/themes/rose-pine/wallpapers/default.png
```

- [ ] **Step 2: Verify**

Run: `ls modules/hyprland/files/themes/rose-pine/wallpapers/`

Expected: at least one `*.png` or `*.jpg` file.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/wallpapers/
git commit -m "themes: rose-pine — add starter wallpaper"
```

---

## Task 9: Create the matugen theme bundle

**Files:**
- Create: `modules/hyprland/files/themes/matugen/meta.toml`
- Create: `modules/hyprland/files/themes/matugen/wallpapers/default.png` (or any image)

- [ ] **Step 1: Create the directory + meta.toml**

```bash
mkdir -p modules/hyprland/files/themes/matugen/wallpapers
```

Path: `modules/hyprland/files/themes/matugen/meta.toml`

```toml
display_name = "Matugen (Material You)"
mode = "matugen"
```

The `mode = "matugen"` line is what `apply-theme.sh` greps for to identify this as the matugen theme.

- [ ] **Step 2: Add at least one starter wallpaper**

```bash
cp modules/hyprland/files/wallpapers/default.png \
   modules/hyprland/files/themes/matugen/wallpapers/default.png
```

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/themes/matugen/
git commit -m "themes: scaffold matugen bundle"
```

---

## Task 10: Delete the now-orphaned waybar custom palettes

The 10 static palettes in `waybar/colors/custom/` were waybar-only. After this work, themes are full per-app bundles or they aren't themes at all. Rose-pine has been moved to its bundle (Task 2). The other 9 are deleted; they can be re-authored as full bundles in follow-up work using rose-pine as the reference.

**Files:**
- Delete: `modules/hyprland/files/waybar/colors/custom/*.css` (9 remaining)
- Delete: `modules/hyprland/files/waybar/colors/colors.css`
- Delete: `modules/hyprland/files/waybar/colors/custom/` (now empty)

- [ ] **Step 1: Confirm what's there**

Run: `ls modules/hyprland/files/waybar/colors/custom/`

Expected: 9 `*.css` files (rose-pine.css already moved).

- [ ] **Step 2: Delete**

```bash
git rm modules/hyprland/files/waybar/colors/custom/*.css
git rm modules/hyprland/files/waybar/colors/colors.css
rmdir modules/hyprland/files/waybar/colors/custom
```

- [ ] **Step 3: Commit**

```bash
git commit -m "waybar: drop orphaned custom palettes (now per-theme bundles)"
```

---

## Task 11: Create minimal rofi config dir

**Files:**
- Create: `modules/hyprland/files/rofi/config.rasi`
- Create: `modules/hyprland/files/rofi/colors/.gitkeep`

The rofi indirection file (`colors/colors.rasi`) is mutable — it gets seeded by `install.sh` and rewritten by `apply-theme.sh`. Don't ship one in the repo. The `.gitkeep` ensures the `colors/` dir exists so the symlink target is valid.

- [ ] **Step 1: Create the dir + minimal config**

```bash
mkdir -p modules/hyprland/files/rofi/colors
touch modules/hyprland/files/rofi/colors/.gitkeep
```

Path: `modules/hyprland/files/rofi/config.rasi`

```
configuration {
    modi: "drun,run";
    show-icons: true;
    icon-theme: "Papirus-Dark";
}

@import "colors/colors.rasi"

* {
    background-color: @bg0;
    text-color:       @fg;
    border-color:     @bg4;
}

window {
    background-color: @bg0;
    border:           2px;
    border-color:     @bg4;
    border-radius:    8px;
    width:            500px;
    padding:          12px;
}

inputbar {
    children:         [prompt, entry];
    background-color: @bg1;
    padding:          8px;
    margin:           0 0 8px 0;
    border-radius:    6px;
}

prompt { padding-right: 8px; color: @blue; }
entry  { background-color: transparent; }

listview {
    lines: 8;
    spacing: 4px;
    scrollbar: false;
}

element { padding: 6px 10px; border-radius: 4px; }
element selected { background-color: @bg3; }
element-text { background-color: transparent; text-color: inherit; }
element-icon { size: 1.2em; padding-right: 8px; background-color: transparent; }
```

This is a minimal-but-usable config; refine to taste later.

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/rofi/
git commit -m "rofi: minimal config wired to colors indirection"
```

---

## Task 12: Create minimal swaync config dir

**Files:**
- Create: `modules/hyprland/files/swaync/config.json`
- Create: `modules/hyprland/files/swaync/style.css`
- Create: `modules/hyprland/files/swaync/colors/.gitkeep`

- [ ] **Step 1: Create dirs + .gitkeep**

```bash
mkdir -p modules/hyprland/files/swaync/colors
touch modules/hyprland/files/swaync/colors/.gitkeep
```

- [ ] **Step 2: Write minimal config.json**

Path: `modules/hyprland/files/swaync/config.json`

```json
{
  "$schema": "/etc/xdg/swaync/configSchema.json",
  "positionX": "right",
  "positionY": "top",
  "control-center-margin-top": 8,
  "control-center-margin-bottom": 8,
  "control-center-margin-right": 8,
  "control-center-margin-left": 8,
  "notification-icon-size": 48,
  "notification-body-image-height": 100,
  "notification-body-image-width": 200,
  "timeout": 5,
  "timeout-low": 3,
  "timeout-critical": 0,
  "fit-to-screen": false,
  "control-center-width": 380,
  "control-center-height": 600,
  "notification-window-width": 380,
  "keyboard-shortcuts": true,
  "image-visibility": "when-available",
  "transition-time": 200
}
```

- [ ] **Step 3: Write style.css**

Path: `modules/hyprland/files/swaync/style.css`

```css
@import "colors/colors.css";

* {
    font-family: "DM Sans", sans-serif;
    font-size: 14px;
}

.control-center {
    background: @bg0;
    border: 2px solid @bg4;
    border-radius: 12px;
    padding: 12px;
}

.notification-row {
    background: @bg1;
    border-radius: 8px;
    margin-bottom: 6px;
}

.notification {
    background: transparent;
    color: @fg;
    padding: 10px;
}

.notification-default-action {
    background: transparent;
    border-radius: 8px;
}

.notification-default-action:hover {
    background: @bg3;
}

.close-button {
    background: @red;
    color: @bg0;
    border-radius: 50%;
    margin: 4px;
    padding: 2px 6px;
}
```

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/swaync/
git commit -m "swaync: minimal config wired to colors indirection"
```

---

## Task 13: Create minimal wlogout config dir

**Files:**
- Create: `modules/hyprland/files/wlogout/layout`
- Create: `modules/hyprland/files/wlogout/style.css`
- Create: `modules/hyprland/files/wlogout/colors/.gitkeep`

- [ ] **Step 1: Create dirs + .gitkeep**

```bash
mkdir -p modules/hyprland/files/wlogout/colors
touch modules/hyprland/files/wlogout/colors/.gitkeep
```

- [ ] **Step 2: Write minimal layout**

Path: `modules/hyprland/files/wlogout/layout`

```
{
    "label" : "lock",
    "action" : "loginctl lock-session",
    "text" : "Lock",
    "keybind" : "l"
}
{
    "label" : "logout",
    "action" : "hyprctl dispatch exit",
    "text" : "Logout",
    "keybind" : "e"
}
{
    "label" : "shutdown",
    "action" : "systemctl poweroff",
    "text" : "Shutdown",
    "keybind" : "s"
}
{
    "label" : "reboot",
    "action" : "systemctl reboot",
    "text" : "Reboot",
    "keybind" : "r"
}
```

- [ ] **Step 3: Write style.css**

Path: `modules/hyprland/files/wlogout/style.css`

```css
@import "colors/colors.css";

* {
    background-image: none;
    box-shadow: none;
    font-family: "DM Sans", sans-serif;
    font-size: 18px;
    color: @fg;
}

window {
    background-color: alpha(@bg0, 0.85);
}

button {
    border-radius: 12px;
    border: 2px solid @bg4;
    background-color: @bg1;
    margin: 12px;
    padding: 24px;
}

button:hover, button:focus {
    background-color: @bg3;
    border-color: @blue;
    outline-style: none;
}
```

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/wlogout/
git commit -m "wlogout: minimal config wired to colors indirection"
```

---

## Task 14: Update kitty.conf to use the indirection

**Files:**
- Modify: `modules/hyprland/files/kitty/kitty.conf:1`

- [ ] **Step 1: Change the include line**

Current first line: `include colors/matugen.conf`

Change to: `include colors/colors.conf`

- [ ] **Step 2: Verify**

Run: `head -1 modules/hyprland/files/kitty/kitty.conf`

Expected: `include colors/colors.conf`

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/kitty/kitty.conf
git commit -m "kitty: source colors indirection instead of matugen.conf directly"
```

---

## Task 15: Update hyprland.conf to use the indirection

**Files:**
- Modify: `modules/hyprland/files/hypr/hyprland.conf:12`

- [ ] **Step 1: Change the source line**

Current line 12: `source = ~/.config/hypr/colors/matugen.conf`

Change to: `source = ~/.config/hypr/colors/colors.conf`

- [ ] **Step 2: Verify**

Run: `grep -n "colors.conf" modules/hyprland/files/hypr/hyprland.conf`

Expected: `12:source = ~/.config/hypr/colors/colors.conf`

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/hypr/hyprland.conf
git commit -m "hypr: source colors indirection instead of matugen.conf directly"
```

---

## Task 16: Update root waybar style.css to use indirection

**Files:**
- Modify: `modules/hyprland/files/waybar/style.css:1`

This file is the initial default — it gets overridden by the layout switcher's symlink at runtime, but ship it consistent for the bootstrap case.

- [ ] **Step 1: Change the @import**

Current first line: `@import 'colors/matugen.css';`

Change to: `@import 'colors/colors.css';`

- [ ] **Step 2: Verify**

Run: `head -1 modules/hyprland/files/waybar/style.css`

Expected: `@import 'colors/colors.css';`

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/waybar/style.css
git commit -m "waybar: root style imports colors indirection"
```

---

## Task 17: Add new symlinks + packages to module.toml

**Files:**
- Modify: `modules/hyprland/module.toml`

- [ ] **Step 1: Add `swaync` and `wlogout` to the pacman packages**

Find the existing `[[packages]]` block with `manager = "pacman"`. Add `"swaync"` and `"wlogout"` to the `names` array (alongside `"rofi"`).

- [ ] **Step 2: Add four new `[[symlinks]]` entries**

Append to `module.toml`:

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

- [ ] **Step 3: Verify**

Run: `grep -E 'swaync|wlogout|themes' modules/hyprland/module.toml`

Expected: lines mentioning `swaync` and `wlogout` in packages, plus four `dst = "~/.config/<thing>"` symlink lines.

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/module.toml
git commit -m "hyprland: add themes/rofi/swaync/wlogout symlinks + packages"
```

---

## Task 18: Add indirection-seeding to install.sh

**Files:**
- Modify: `modules/hyprland/install.sh`

- [ ] **Step 1: Append the seeding block**

Append to `modules/hyprland/install.sh` (after the existing matugen first-run block):

```bash
# --- Theme indirection first-run seed ---------------------------------
# Indirection files are mutable (rewritten by apply-theme.sh on every
# theme switch). Quill can't manage them as [[symlinks]] or [[files]] —
# this seeds them with rose-pine on first install and never touches
# them again.
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
seed_indirection "$HOME/.config/rofi/colors/colors.rasi"    '@import "../../themes/rose-pine/rofi.rasi"'
seed_indirection "$HOME/.config/swaync/colors/colors.css"   '@import "../../themes/rose-pine/swaync.css";'
seed_indirection "$HOME/.config/wlogout/colors/colors.css"  '@import "../../themes/rose-pine/wlogout.css";'

# Seed state so the first Super+D shows the right "current" mark
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
mkdir -p "$STATE_DIR"
[[ -f "$STATE_DIR/current" ]] || echo rose-pine > "$STATE_DIR/current"
```

- [ ] **Step 2: Verify the script still parses**

Run: `bash -n modules/hyprland/install.sh`

Expected: no output (syntax OK).

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/install.sh
git commit -m "hyprland: install.sh seeds theme indirection files on first run"
```

---

## Task 19: Write apply-theme.sh

**Files:**
- Create: `modules/hyprland/files/hypr/scripts/apply-theme.sh`

This is the central script. Theme-switcher and wallpaper-picker both call into it.

- [ ] **Step 1: Write the script**

Path: `modules/hyprland/files/hypr/scripts/apply-theme.sh`

```bash
#!/usr/bin/env bash
# Apply a theme: rewrite indirection files, set wallpaper, reload affected apps.
# Called by theme-switcher.sh and (indirectly) wallpaper-picker.sh.
#
# Usage: apply-theme.sh <theme-name>
set -euo pipefail

THEME="${1:-}"
[[ -z "$THEME" ]] && { echo "usage: $0 <theme-name>" >&2; exit 1; }

THEMES_DIR="$HOME/.config/themes"
THEME_DIR="$THEMES_DIR/$THEME"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
WALLPAPERS_STATE="$STATE_DIR/wallpapers.txt"
CURRENT_STATE="$STATE_DIR/current"

if [[ ! -d "$THEME_DIR" ]]; then
  notify-send "Theme error" "Unknown theme: $THEME" -u critical
  echo "unknown theme: $THEME" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"
touch "$WALLPAPERS_STATE"

# Detect mode (matugen or static) from meta.toml
mode="static"
if [[ -f "$THEME_DIR/meta.toml" ]] && grep -q '^mode = "matugen"' "$THEME_DIR/meta.toml"; then
  mode="matugen"
fi

# --- Build wallpaper pool -----------------------------------------------------
declare -a pool=()
if [[ "$mode" == "matugen" ]]; then
  # union of every theme's wallpapers/
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    find "$THEMES_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 | sort -z
  )
else
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    find "$THEME_DIR/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 2>/dev/null | sort -z
  )
fi

# --- Resolve wallpaper: last-used or first in pool ---------------------------
wallpaper=""
saved=$(grep "^${THEME}:" "$WALLPAPERS_STATE" | head -n1 | cut -d':' -f2-)
if [[ -n "$saved" && -f "$saved" ]]; then
  wallpaper="$saved"
elif (( ${#pool[@]} > 0 )); then
  wallpaper="${pool[0]}"
  # persist as default
  sed -i "/^${THEME}:/d" "$WALLPAPERS_STATE"
  printf '%s:%s\n' "$THEME" "$wallpaper" >> "$WALLPAPERS_STATE"
fi

# --- Rewrite indirection files ------------------------------------------------
write_one() {
  local file="$1" content="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$content" > "$file"
}

if [[ "$mode" == "matugen" ]]; then
  write_one "$HOME/.config/hypr/colors/colors.conf"    'source = ~/.config/hypr/colors/matugen.conf'
  write_one "$HOME/.config/waybar/colors/colors.css"   '@import "matugen.css";'
  write_one "$HOME/.config/kitty/colors/colors.conf"   'include matugen.conf'
  write_one "$HOME/.config/rofi/colors/colors.rasi"    '@import "matugen.rasi"'
  write_one "$HOME/.config/swaync/colors/colors.css"   '@import "matugen.css";'
  write_one "$HOME/.config/wlogout/colors/colors.css"  '@import "matugen.css";'
else
  write_one "$HOME/.config/hypr/colors/colors.conf"    "source = ~/.config/themes/${THEME}/hypr.conf"
  write_one "$HOME/.config/waybar/colors/colors.css"   "@import \"../../themes/${THEME}/waybar.css\";"
  write_one "$HOME/.config/kitty/colors/colors.conf"   "include ~/.config/themes/${THEME}/kitty.conf"
  write_one "$HOME/.config/rofi/colors/colors.rasi"    "@import \"../../themes/${THEME}/rofi.rasi\""
  write_one "$HOME/.config/swaync/colors/colors.css"   "@import \"../../themes/${THEME}/swaync.css\";"
  write_one "$HOME/.config/wlogout/colors/colors.css"  "@import \"../../themes/${THEME}/wlogout.css\";"
fi

# --- Wallpaper + reload pipeline ---------------------------------------------
if [[ "$mode" == "matugen" ]]; then
  if [[ -n "$wallpaper" ]]; then
    # matugen post-hooks regenerate matugen.* and reload each app
    matugen image "$wallpaper"
  fi
else
  if [[ -n "$wallpaper" ]]; then
    awww img "$wallpaper" \
      --transition-type center --transition-fps 165 \
      --transition-step 30 --transition-duration 2 \
      >/dev/null 2>&1 || true
  fi
  hyprctl reload >/dev/null 2>&1 || true
  pkill -SIGUSR2 waybar 2>/dev/null || true
  if pids=$(pidof kitty 2>/dev/null) && [[ -n "$pids" ]]; then
    kill -SIGUSR1 $pids 2>/dev/null || true
  fi
  if pgrep -x swaync >/dev/null 2>&1; then
    pkill swaync 2>/dev/null || true
    (swaync >/dev/null 2>&1 &)
  fi
fi

echo "$THEME" > "$CURRENT_STATE"
notify-send "Theme" "$THEME"
```

- [ ] **Step 2: Make executable + sanity-check syntax**

```bash
chmod +x modules/hyprland/files/hypr/scripts/apply-theme.sh
bash -n modules/hyprland/files/hypr/scripts/apply-theme.sh
```

Expected: no output from `bash -n` (syntax OK).

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/apply-theme.sh
git commit -m "hypr: apply-theme.sh — theme switcher core"
```

---

## Task 20: Write theme-switcher.sh

**Files:**
- Create: `modules/hyprland/files/hypr/scripts/theme-switcher.sh`

- [ ] **Step 1: Write the script**

Path: `modules/hyprland/files/hypr/scripts/theme-switcher.sh`

```bash
#!/usr/bin/env bash
# Rofi theme picker: list theme bundles, mark current, apply on selection.
# Bound to Super+D.
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
APPLY="$HOME/.config/hypr/scripts/apply-theme.sh"

current=""
[[ -f "$STATE_DIR/current" ]] && current=$(cat "$STATE_DIR/current")

# Build labeled list: optional display_name from meta.toml, fall back to dir name
declare -A label_to_dir=()
mapfile -t dirs < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' | sort)

menu=""
for d in "${dirs[@]}"; do
  label="$d"
  if [[ -f "$THEMES_DIR/$d/meta.toml" ]]; then
    dn=$(grep -E '^display_name' "$THEMES_DIR/$d/meta.toml" | head -n1 | cut -d'"' -f2 || true)
    [[ -n "$dn" ]] && label="$dn"
  fi
  label_to_dir["$label"]="$d"
  if [[ "$d" == "$current" ]]; then
    menu+="● $label"$'\n'
  else
    menu+="  $label"$'\n'
  fi
done

selected=$(printf '%s' "$menu" | rofi -dmenu -i -p "Theme")
[[ -z "$selected" ]] && exit 0

# Strip the prefix marker
selected="${selected#● }"
selected="${selected#  }"

theme="${label_to_dir[$selected]:-}"
[[ -z "$theme" ]] && { notify-send "Theme" "Unknown selection: $selected" -u critical; exit 1; }

exec "$APPLY" "$theme"
```

- [ ] **Step 2: Make executable + sanity-check**

```bash
chmod +x modules/hyprland/files/hypr/scripts/theme-switcher.sh
bash -n modules/hyprland/files/hypr/scripts/theme-switcher.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/theme-switcher.sh
git commit -m "hypr: theme-switcher.sh — Super+D rofi picker"
```

---

## Task 21: Write wallpaper-picker.sh

**Files:**
- Create: `modules/hyprland/files/hypr/scripts/wallpaper-picker.sh`

- [ ] **Step 1: Write the script**

Path: `modules/hyprland/files/hypr/scripts/wallpaper-picker.sh`

```bash
#!/usr/bin/env bash
# Rofi wallpaper picker. In matugen mode, pool = union of every theme's
# wallpapers/ and selection triggers `matugen image`. In static mode,
# pool = current theme only and selection just changes the wallpaper.
# Bound to Super+Shift+D.
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
WALLPAPERS_STATE="$STATE_DIR/wallpapers.txt"
CURRENT_STATE="$STATE_DIR/current"

if [[ ! -f "$CURRENT_STATE" ]]; then
  notify-send "Wallpaper" "No active theme — run Super+D first" -u critical
  exit 1
fi
THEME=$(cat "$CURRENT_STATE")
THEME_DIR="$THEMES_DIR/$THEME"

# Detect matugen mode
mode="static"
if [[ -f "$THEME_DIR/meta.toml" ]] && grep -q '^mode = "matugen"' "$THEME_DIR/meta.toml"; then
  mode="matugen"
fi

# Build pool
declare -a pool=()
if [[ "$mode" == "matugen" ]]; then
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    find "$THEMES_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 | sort -z
  )
else
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    find "$THEME_DIR/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 2>/dev/null | sort -z
  )
fi

if (( ${#pool[@]} == 0 )); then
  notify-send "Wallpaper" "No wallpapers found for theme: $THEME" -u critical
  exit 1
fi

mkdir -p "$STATE_DIR"
touch "$WALLPAPERS_STATE"
current_wp=$(grep "^${THEME}:" "$WALLPAPERS_STATE" | head -n1 | cut -d':' -f2-)

# Build rofi menu with thumbnails
menu=""
for wp in "${pool[@]}"; do
  base=$(basename "$wp")
  if [[ "$wp" == "$current_wp" ]]; then
    menu+="● ${base}"$'\0'"icon"$'\x1f'"${wp}"$'\n'
  else
    menu+="${base}"$'\0'"icon"$'\x1f'"${wp}"$'\n'
  fi
done

selected=$(printf '%b' "$menu" | rofi -dmenu -i -show-icons -p "Wallpaper")
[[ -z "$selected" ]] && exit 0
selected="${selected#● }"

# Resolve full path
selected_path=""
for wp in "${pool[@]}"; do
  if [[ "$(basename "$wp")" == "$selected" ]]; then
    selected_path="$wp"; break
  fi
done
[[ -z "$selected_path" ]] && { notify-send "Wallpaper" "Could not resolve: $selected" -u critical; exit 1; }

# Persist
sed -i "/^${THEME}:/d" "$WALLPAPERS_STATE"
printf '%s:%s\n' "$THEME" "$selected_path" >> "$WALLPAPERS_STATE"

# Apply
if [[ "$mode" == "matugen" ]]; then
  matugen image "$selected_path"
else
  awww img "$selected_path" \
    --transition-type wipe --transition-fps 165 \
    --transition-step 30 --transition-duration 2 \
    >/dev/null 2>&1 || true
fi

notify-send "Wallpaper" "$(basename "$selected_path")"
```

- [ ] **Step 2: Make executable + sanity-check**

```bash
chmod +x modules/hyprland/files/hypr/scripts/wallpaper-picker.sh
bash -n modules/hyprland/files/hypr/scripts/wallpaper-picker.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/wallpaper-picker.sh
git commit -m "hypr: wallpaper-picker.sh — Super+Shift+D rofi picker"
```

---

## Task 22: Update hyprland.conf binds

**Files:**
- Modify: `modules/hyprland/files/hypr/hyprland.conf:249`

- [ ] **Step 1: Replace the existing Super+D bind and add Super+Shift+D**

Current line 249: `bind = $mainMod, D, exec, ~/.local/bin/walset`

Replace with:

```
bind = $mainMod, D, exec, ~/.config/hypr/scripts/theme-switcher.sh
bind = $mainMod SHIFT, D, exec, ~/.config/hypr/scripts/wallpaper-picker.sh
```

- [ ] **Step 2: Verify**

Run: `grep -nE 'D, exec|SHIFT, D' modules/hyprland/files/hypr/hyprland.conf`

Expected: two lines binding theme-switcher.sh and wallpaper-picker.sh; no remaining `walset` reference.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/hypr/hyprland.conf
git commit -m "hypr: bind Super+D to theme-switcher, Super+Shift+D to wallpaper-picker"
```

---

## Task 23: Delete walset scripts

**Files:**
- Delete: `modules/hyprland/files/hypr/scripts/walset.sh`
- Delete: `modules/hyprland/files/hypr/scripts/walset-backend.sh`

- [ ] **Step 1: Delete**

```bash
git rm modules/hyprland/files/hypr/scripts/walset.sh
git rm modules/hyprland/files/hypr/scripts/walset-backend.sh
```

- [ ] **Step 2: Verify**

Run: `ls modules/hyprland/files/hypr/scripts/`

Expected: only `apply-theme.sh`, `theme-switcher.sh`, `wallpaper-picker.sh` (and any other unrelated scripts).

- [ ] **Step 3: Commit**

```bash
git commit -m "hypr: drop walset (subsumed by wallpaper-picker)"
```

---

## Task 24: Rewrite matugen waybar template (canonical vocabulary)

**Files:**
- Modify: `modules/hyprland/files/matugen/templates/colors.css`

The current template iterates over Material color names. Replace with explicit canonical-vocab definitions, then keep emitting Material names below for any future consumer.

- [ ] **Step 1: Overwrite the template**

Path: `modules/hyprland/files/matugen/templates/colors.css`

```css
/*
 * Waybar / swaync / wlogout palette — canonical vocabulary
 * Generated by matugen.
 */

@define-color bg0 {{colors.surface.default.hex}};
@define-color bg1 {{colors.surface_container_low.default.hex}};
@define-color bg2 {{colors.surface_container.default.hex}};
@define-color bg3 {{colors.surface_container_high.default.hex}};
@define-color bg4 {{colors.surface_container_highest.default.hex}};

@define-color fg {{colors.on_surface.default.hex}};

@define-color red    {{colors.error.default.hex}};
@define-color orange {{colors.tertiary.default.hex}};
@define-color yellow {{colors.secondary_fixed_dim.default.hex}};
@define-color green  {{colors.primary.default.hex}};
@define-color aqua   {{colors.tertiary_container.default.hex}};
@define-color blue   {{colors.secondary.default.hex}};
@define-color purple {{colors.inverse_primary.default.hex}};

@define-color grey0 {{colors.outline_variant.default.hex}};
@define-color grey1 {{colors.outline.default.hex}};
@define-color grey2 {{colors.on_surface_variant.default.hex}};

/* Material You names also emitted for any consumer that wants them */
{% for name, value in colors %}
@define-color {{name}} {{value.default.hex}};
{% endfor %}
```

> Note: the templating language matugen uses is Tera/Liquid-like — verify the loop syntax matches what the existing template uses (the original used `<* for ... *>` style; copy that style instead of `{% %}` if so).

- [ ] **Step 2: Verify by re-running matugen against the default wallpaper**

```bash
matugen image modules/hyprland/files/wallpapers/default.png
cat ~/.config/waybar/colors/matugen.css | head -20
```

Expected: the first ~16 lines define `bg0`, `bg1`, ..., `purple`, `grey0..grey2`. No errors.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/matugen/templates/colors.css
git commit -m "matugen: waybar template emits canonical bg0/fg/accent vocabulary"
```

---

## Task 25: Rewrite matugen hyprland template (canonical vocabulary)

**Files:**
- Modify: `modules/hyprland/files/matugen/templates/hyprland-colors.conf`

- [ ] **Step 1: Overwrite the template**

Path: `modules/hyprland/files/matugen/templates/hyprland-colors.conf`

```
$image = {{image}}

$bg0 = rgb({{colors.surface.default.hex_stripped}})
$bg1 = rgb({{colors.surface_container_low.default.hex_stripped}})
$bg2 = rgb({{colors.surface_container.default.hex_stripped}})
$bg3 = rgb({{colors.surface_container_high.default.hex_stripped}})
$bg4 = rgb({{colors.surface_container_highest.default.hex_stripped}})

$fg = rgb({{colors.on_surface.default.hex_stripped}})

$red    = rgb({{colors.error.default.hex_stripped}})
$orange = rgb({{colors.tertiary.default.hex_stripped}})
$yellow = rgb({{colors.secondary_fixed_dim.default.hex_stripped}})
$green  = rgb({{colors.primary.default.hex_stripped}})
$aqua   = rgb({{colors.tertiary_container.default.hex_stripped}})
$blue   = rgb({{colors.secondary.default.hex_stripped}})
$purple = rgb({{colors.inverse_primary.default.hex_stripped}})

$grey0 = rgb({{colors.outline_variant.default.hex_stripped}})
$grey1 = rgb({{colors.outline.default.hex_stripped}})
$grey2 = rgb({{colors.on_surface_variant.default.hex_stripped}})
```

> Use whichever loop/iteration syntax the original template used if you want to preserve the Material-name emissions. The above keeps it minimal — only canonical names.

- [ ] **Step 2: Verify**

```bash
matugen image modules/hyprland/files/wallpapers/default.png
head -20 ~/.config/hypr/colors/matugen.conf
```

Expected: `$bg0`, `$bg1`, ..., `$purple`, `$grey0..grey2` definitions.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/matugen/templates/hyprland-colors.conf
git commit -m "matugen: hyprland template emits canonical vocabulary"
```

---

## Task 26: Rewrite matugen kitty template (canonical 16-color)

**Files:**
- Modify: `modules/hyprland/files/matugen/templates/kitty-colors.conf`

- [ ] **Step 1: Overwrite the template**

Path: `modules/hyprland/files/matugen/templates/kitty-colors.conf`

```
background  {{colors.surface.dark.hex}}
foreground  {{colors.on_surface.dark.hex}}
cursor      {{colors.on_surface.dark.hex}}

color0  {{colors.surface.dark.hex}}
color1  {{colors.error.dark.hex}}
color2  {{colors.primary.dark.hex}}
color3  {{colors.secondary_fixed_dim.dark.hex}}
color4  {{colors.secondary.dark.hex}}
color5  {{colors.inverse_primary.dark.hex}}
color6  {{colors.tertiary_container.dark.hex}}
color7  {{colors.on_surface.dark.hex}}

color8  {{colors.outline_variant.dark.hex}}
color9  {{colors.error.dark.hex}}
color10 {{colors.primary.dark.hex}}
color11 {{colors.secondary_fixed_dim.dark.hex}}
color12 {{colors.secondary.dark.hex}}
color13 {{colors.inverse_primary.dark.hex}}
color14 {{colors.tertiary_container.dark.hex}}
color15 {{colors.on_surface.dark.hex}}
```

- [ ] **Step 2: Verify**

```bash
matugen image modules/hyprland/files/wallpapers/default.png
cat ~/.config/kitty/colors/matugen.conf
```

Expected: `background`, `foreground`, `cursor`, and `color0..color15` defined. Reload kitty (`kill -SIGUSR1 $(pidof kitty)`) and confirm colors aren't broken.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/matugen/templates/kitty-colors.conf
git commit -m "matugen: kitty template — canonical 16-color mapping"
```

---

## Task 27: Rewrite matugen rofi template + fix output_path

**Files:**
- Modify: `modules/hyprland/files/matugen/templates/rofi-colors.rasi`
- Modify: `modules/hyprland/files/matugen/config.toml`

The existing rofi template writes to `~/.config/rofi/launchers/shared/matugen.rasi` (a leftover from old setup). Change it to `~/.config/rofi/colors/matugen.rasi` so the indirection from `colors/colors.rasi` resolves correctly with `@import "matugen.rasi"`.

- [ ] **Step 1: Overwrite the template**

Path: `modules/hyprland/files/matugen/templates/rofi-colors.rasi`

```
* {
    bg0:    {{colors.surface.default.hex}};
    bg1:    {{colors.surface_container_low.default.hex}};
    bg2:    {{colors.surface_container.default.hex}};
    bg3:    {{colors.surface_container_high.default.hex}};
    bg4:    {{colors.surface_container_highest.default.hex}};

    fg:     {{colors.on_surface.default.hex}};

    red:    {{colors.error.default.hex}};
    orange: {{colors.tertiary.default.hex}};
    yellow: {{colors.secondary_fixed_dim.default.hex}};
    green:  {{colors.primary.default.hex}};
    aqua:   {{colors.tertiary_container.default.hex}};
    blue:   {{colors.secondary.default.hex}};
    purple: {{colors.inverse_primary.default.hex}};

    grey0:  {{colors.outline_variant.default.hex}};
    grey1:  {{colors.outline.default.hex}};
    grey2:  {{colors.on_surface_variant.default.hex}};
}
```

- [ ] **Step 2: Update the output path in matugen/config.toml**

In `modules/hyprland/files/matugen/config.toml`, find the `[templates.rofi]` section and change:

```toml
[templates.rofi]
input_path = '~/.config/matugen/templates/rofi-colors.rasi'
output_path = '~/.config/rofi/launchers/shared/matugen.rasi'
```

to:

```toml
[templates.rofi]
input_path = '~/.config/matugen/templates/rofi-colors.rasi'
output_path = '~/.config/rofi/colors/matugen.rasi'
```

- [ ] **Step 3: Verify**

```bash
matugen image modules/hyprland/files/wallpapers/default.png
cat ~/.config/rofi/colors/matugen.rasi
```

Expected: rasi file with `bg0/...` definitions. The old path `~/.config/rofi/launchers/shared/matugen.rasi` won't be regenerated; remove it manually if it exists (`rm -f ~/.config/rofi/launchers/shared/matugen.rasi`).

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/matugen/templates/rofi-colors.rasi modules/hyprland/files/matugen/config.toml
git commit -m "matugen: rofi template — canonical vocab + write to colors/matugen.rasi"
```

---

## Task 28: Add matugen swaync template

**Files:**
- Create: `modules/hyprland/files/matugen/templates/swaync-colors.css`
- Modify: `modules/hyprland/files/matugen/config.toml`

- [ ] **Step 1: Write the template**

Path: `modules/hyprland/files/matugen/templates/swaync-colors.css`

```css
/*
 * swaync palette — canonical vocabulary
 * Generated by matugen.
 */

@define-color bg0 {{colors.surface.default.hex}};
@define-color bg1 {{colors.surface_container_low.default.hex}};
@define-color bg2 {{colors.surface_container.default.hex}};
@define-color bg3 {{colors.surface_container_high.default.hex}};
@define-color bg4 {{colors.surface_container_highest.default.hex}};

@define-color fg {{colors.on_surface.default.hex}};

@define-color red    {{colors.error.default.hex}};
@define-color orange {{colors.tertiary.default.hex}};
@define-color yellow {{colors.secondary_fixed_dim.default.hex}};
@define-color green  {{colors.primary.default.hex}};
@define-color aqua   {{colors.tertiary_container.default.hex}};
@define-color blue   {{colors.secondary.default.hex}};
@define-color purple {{colors.inverse_primary.default.hex}};

@define-color grey0 {{colors.outline_variant.default.hex}};
@define-color grey1 {{colors.outline.default.hex}};
@define-color grey2 {{colors.on_surface_variant.default.hex}};
```

- [ ] **Step 2: Add the template section to matugen/config.toml**

Append to `modules/hyprland/files/matugen/config.toml`:

```toml
[templates.swaync]
input_path = '~/.config/matugen/templates/swaync-colors.css'
output_path = '~/.config/swaync/colors/matugen.css'
post_hook = 'pkill swaync; swaync >/dev/null 2>&1 &'
```

- [ ] **Step 3: Verify**

```bash
matugen image modules/hyprland/files/wallpapers/default.png
cat ~/.config/swaync/colors/matugen.css | head -10
```

Expected: `@define-color bg0 ...;` etc. swaync restarts.

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/matugen/templates/swaync-colors.css modules/hyprland/files/matugen/config.toml
git commit -m "matugen: add swaync template"
```

---

## Task 29: Add matugen wlogout template

**Files:**
- Create: `modules/hyprland/files/matugen/templates/wlogout-colors.css`
- Modify: `modules/hyprland/files/matugen/config.toml`

- [ ] **Step 1: Write the template**

Path: `modules/hyprland/files/matugen/templates/wlogout-colors.css`

```css
/*
 * wlogout palette — canonical vocabulary
 * Generated by matugen.
 */

@define-color bg0 {{colors.surface.default.hex}};
@define-color bg1 {{colors.surface_container_low.default.hex}};
@define-color bg2 {{colors.surface_container.default.hex}};
@define-color bg3 {{colors.surface_container_high.default.hex}};
@define-color bg4 {{colors.surface_container_highest.default.hex}};

@define-color fg {{colors.on_surface.default.hex}};

@define-color red    {{colors.error.default.hex}};
@define-color orange {{colors.tertiary.default.hex}};
@define-color yellow {{colors.secondary_fixed_dim.default.hex}};
@define-color green  {{colors.primary.default.hex}};
@define-color aqua   {{colors.tertiary_container.default.hex}};
@define-color blue   {{colors.secondary.default.hex}};
@define-color purple {{colors.inverse_primary.default.hex}};

@define-color grey0 {{colors.outline_variant.default.hex}};
@define-color grey1 {{colors.outline.default.hex}};
@define-color grey2 {{colors.on_surface_variant.default.hex}};
```

- [ ] **Step 2: Add the template section to matugen/config.toml**

Append to `modules/hyprland/files/matugen/config.toml`:

```toml
[templates.wlogout]
input_path = '~/.config/matugen/templates/wlogout-colors.css'
output_path = '~/.config/wlogout/colors/matugen.css'
# wlogout has no daemon — config is read on each launch. No post_hook needed.
```

- [ ] **Step 3: Verify**

```bash
matugen image modules/hyprland/files/wallpapers/default.png
cat ~/.config/wlogout/colors/matugen.css | head -10
```

Expected: `@define-color bg0 ...;` etc.

- [ ] **Step 4: Commit**

```bash
git add modules/hyprland/files/matugen/templates/wlogout-colors.css modules/hyprland/files/matugen/config.toml
git commit -m "matugen: add wlogout template"
```

---

## Task 30: End-to-end smoke test

**Files:** none (manual validation)

This is the verification gate. Run through every flow before declaring complete.

- [ ] **Step 1: Apply the module**

```bash
go build -o ./bin/quill ./cmd/quill
./bin/quill apply hyprland
```

Expected: no errors. Verify symlinks:

```bash
ls -la ~/.config/themes ~/.config/rofi ~/.config/swaync ~/.config/wlogout
```

Expected: each is a symlink into `~/Development/.dotfiles/modules/hyprland/files/...`.

Verify the indirection seeds:

```bash
cat ~/.config/{hypr,waybar,kitty,rofi,swaync,wlogout}/colors/colors.* 2>&1
```

Expected: each is one line pointing into `themes/rose-pine/...`.

- [ ] **Step 2: Confirm rose-pine renders correctly out of the box**

Reload Hyprland (`hyprctl reload`), reload waybar (`pkill -SIGUSR2 waybar` or restart), reload kitty (`kill -SIGUSR1 $(pidof kitty)`).

Expected: Hyprland borders, waybar, kitty all show rose-pine colors (`#191724` background, `#e0def4` foreground).

- [ ] **Step 3: Open theme picker, switch to matugen**

Press Super+D. Expected: rofi opens with `Rose Pine` (marked `●`) and `Matugen (Material You)`. Pick matugen.

Expected: wallpaper changes (matugen's default), all 6 apps re-color to Material You palette derived from that wallpaper. State file shows `matugen`:

```bash
cat "${XDG_STATE_HOME:-$HOME/.local/state}/themes/current"
```

- [ ] **Step 4: Switch back to rose-pine**

Super+D → pick `Rose Pine`. Expected: wallpaper changes to rose-pine's wallpaper, all apps re-color back to rose-pine.

- [ ] **Step 5: Wallpaper picker in static mode**

Super+Shift+D. Expected: rofi shows only rose-pine's wallpapers (1 image). Pick it.

Expected: wallpaper transitions; no palette change; no app reload churn.

- [ ] **Step 6: Wallpaper picker in matugen mode**

Super+D → matugen. Then Super+Shift+D. Expected: rofi shows the union pool (rose-pine's wallpaper + matugen's wallpaper). Pick the other one.

Expected: matugen runs, palette regenerates from the picked image, all apps reload with new colors.

- [ ] **Step 7: Idempotency check**

```bash
./bin/quill apply hyprland
```

Expected: no churn — the indirection files are NOT overwritten (because `seed_indirection` only writes if the file doesn't exist).

- [ ] **Step 8: Confirm walset is gone**

```bash
ls modules/hyprland/files/hypr/scripts/
grep -n walset modules/hyprland/files/hypr/hyprland.conf
```

Expected: no `walset.sh` / `walset-backend.sh`; no walset references in hyprland.conf.

- [ ] **Step 9: Final commit (if anything changed during testing — usually nothing)**

If smoke testing surfaced any fixes, commit them with descriptive messages. Otherwise skip.

---

## Follow-up work (not in this plan)

- Add any net-new static themes (for example `monochrome`/`nord` variants) as full bundles using the canonical palette vocabulary and full 6-app coverage.
- Refine rofi/swaync/wlogout `style.css` files to taste.
- Consider a `themes/` migration helper script if author burden becomes annoying.
- Revisit Waybar layouts (`layouts/alchemy`, `layouts/subtle`, `layouts/ultra_minimal`, `layouts/velvetline`, `layouts/waybar-v1`, `layouts/waybar-v2`): audit module parity and theme behavior, then decide whether to standardize one default or keep multiple curated options.
- If multiple Waybar layouts remain, add a layout switcher keybind (e.g., rofi picker + symlink flip for `~/.config/waybar/config.jsonc` and `~/.config/waybar/style.css`, then Waybar restart).
