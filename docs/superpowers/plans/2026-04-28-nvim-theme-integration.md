# Neovim Theme Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tie Neovim into the existing theme framework so Super+D switches nvim's colorscheme alongside hypr/waybar/kitty/rofi/swaync/wlogout. Each static theme picks an existing tuned plugin (catppuccin, rose-pine, kanagawa, …); matugen mode renders a small generated colorscheme from the canonical palette.

**Architecture:** Each `themes/<name>/` gains an `nvim.lua` spec file declaring `{ plugin = <lazy spec>, scheme = "..." }`. A dispatcher (`modules/neovim/files/nvim/lua/config/theme.lua`) reads `~/.local/state/themes/current`, requires the matching spec, and runs `vim.cmd.colorscheme(spec.scheme)`. Lazy.nvim registers all 10 colorscheme plugins: the active theme's plugin keeps `lazy = false, priority = 1000` so it loads at startup, while inactive ones get rewritten to `lazy = true` so they're installed up front but only loaded on switch via `require("lazy").load(...)`. (An earlier `cond`-based variant was replaced because `cond = false` blocked install entirely, breaking pre-download.) For matugen, a new matugen template emits a self-applying nvim colorscheme file (`~/.config/nvim/colors/matugen.lua`) so the dispatcher's matugen path is just `dofile()`-ing that file (using `:colorscheme matugen` is a no-op when matugen is already current, so wallpaper changes wouldn't refresh). Live-reload across running nvim instances is via a `Signal` autocmd on `SIGUSR1`, sent by `apply-theme.sh` after writing state, and by matugen's nvim post-hook on wallpaper changes. Each theme's spec also accepts an optional `post = function() ... end` hook that runs after `:colorscheme` to override highlights.

**Tech Stack:** Neovim 0.10+ (Signal autocmd), lazy.nvim (plugin manager — already in use), matugen (template adds an nvim emitter), bash (one-line addition to apply-theme.sh). No Go changes.

**Spec:** [`docs/superpowers/specs/2026-04-25-theme-switcher-design.md`](../specs/2026-04-25-theme-switcher-design.md) (updated by Task 1)

---

## Status (2026-04-28)

All tasks complete and shipping on `startover` (commits `d6ca86e` for the integration, `77140b8` for lualine `theme = "auto"` and tokyo-night tree transparency). Notes on what changed during implementation:

- Inactive colorscheme plugins are gated with `lazy = true` (not `cond` as originally written) — `cond = false` blocks installation, defeating the pre-download goal.
- Matugen path uses `dofile()` instead of `vim.cmd.colorscheme("matugen")` — vim treats setting the colorscheme to its current value as a no-op even if the underlying file changed, so `:colorscheme matugen` wouldn't refresh palettes on wallpaper switches while matugen was active.
- Spec gained an optional `post = function()` hook (demoed on kanagawa to clear `LineNr`/`SignColumn` backgrounds and on tokyo-night for `NvimTree*` transparency). Helpers stay inline per-theme; extract to a shared module if a third theme repeats the same pattern.

The `[whisper]` section's `gpu_device` selector and the systemd `__NV_PRIME_RENDER_OFFLOAD=1` drop-in shipped separately under the voxtype follow-up (commit `9836354`); not part of this plan.

---

## Plugin assignments

| Theme | Plugin | Scheme name |
|---|---|---|
| catppuccin | `catppuccin/nvim` | `catppuccin-mocha` |
| rose-pine | `rose-pine/neovim` | `rose-pine-moon` |
| kanagawa | `rebelot/kanagawa.nvim` | `kanagawa` |
| tokyo-night | `folke/tokyonight.nvim` | `tokyonight-moon` |
| nightfox | `EdenEast/nightfox.nvim` | `nightfox` |
| everforest-dark | `sainnhe/everforest` | `everforest` |
| gruvbox-dark | `ellisonleao/gruvbox.nvim` | `gruvbox` |
| nord-darker | `gbprod/nord.nvim` | `nord` |
| e-ink | `e-ink-colorscheme/e-ink.nvim` | `e-ink` |
| noir | `dzfrias/noir.nvim` | `noir` |
| matugen | (none — generated colorscheme file) | `matugen` |

Per-theme configuration is intentionally minimal — defaults across the board, with `transparent`/`transparent_background` set where the plugin supports it. The previous catppuccin `custom_highlights` block is dropped; revisit later if any theme feels rough.

---

## File Structure

**New files:**
```
modules/hyprland/files/themes/<theme>/nvim.lua          # × 10 (one per static theme)
modules/hyprland/files/matugen/templates/nvim-colors.lua
modules/neovim/files/nvim/lua/config/theme.lua
```

**Modified files:**
```
docs/superpowers/specs/2026-04-25-theme-switcher-design.md  # nvim moves into scope
modules/hyprland/files/matugen/config.toml                  # add [templates.nvim]
modules/hyprland/files/hypr/scripts/apply-theme.sh          # add SIGUSR1 reload
modules/neovim/files/nvim/init.lua                          # require theme + Signal autocmd
modules/neovim/files/nvim/lua/plugins/colorscheme.lua       # full rewrite — register all 10 plugins
modules/neovim/files/nvim/lua/config/autocmds.lua           # (alternative home for Signal autocmd)
```

**Deleted files:** none.

---

## Task 1: Update the theme-switcher spec

**Files:**
- Modify: `docs/superpowers/specs/2026-04-25-theme-switcher-design.md`

- [ ] **Step 1: Move nvim out of "Out of scope"**

In the "Scope" section, remove `nvim` from the "Out of scope" bullet that lists `GTK theme name, VSCodium, Discord/vesktop, neovim, spicetify`. Mention nvim in the "In scope (apps that get themed)" line.

- [ ] **Step 2: Add an `nvim` row to the per-app syntax block**

In the "Variable vocabulary" section, append to the per-app syntax bullets:

```
- nvim: each `themes/<name>/nvim.lua` returns `{ plugin = <lazy spec>, scheme = "..." }`; a dispatcher reads `~/.local/state/themes/current` and runs `vim.cmd.colorscheme(spec.scheme)`. Matugen renders a self-applying colorscheme at `~/.config/nvim/colors/matugen.lua`.
```

- [ ] **Step 3: Update "Out of scope (recap)"**

Remove `nvim` from the recap bullet at the bottom of the doc.

- [ ] **Step 4: Add a "Status (2026-04-28)" note at the top**

Below the existing 2026-04-26 status, add:

```
> **Status (2026-04-28):** nvim integration in progress per `docs/superpowers/plans/2026-04-28-nvim-theme-integration.md`. After it lands, the visible-shell set is hypr/waybar/kitty/rofi/swaync/wlogout/nvim.
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-04-25-theme-switcher-design.md
git commit -m "spec: theme-switcher — bring nvim into scope"
```

---

## Task 2: Author rose-pine `nvim.lua` (reference)

**Files:**
- Create: `modules/hyprland/files/themes/rose-pine/nvim.lua`

This is the reference spec — Task 3 mirrors the same shape across the other 9 static themes.

- [ ] **Step 1: Write the spec**

Path: `modules/hyprland/files/themes/rose-pine/nvim.lua`

```lua
return {
  plugin = {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        variant = "moon",
        styles = { transparency = true },
      })
    end,
  },
  scheme = "rose-pine-moon",
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/themes/rose-pine/nvim.lua
git commit -m "themes: rose-pine — nvim spec"
```

---

## Task 3: Author the remaining 9 static themes' `nvim.lua`

**Files:**
- Create: `modules/hyprland/files/themes/<theme>/nvim.lua` × 9

Each file is small and follows the rose-pine shape. Copy/paste, then commit them as a single batch.

- [ ] **Step 1: catppuccin**

Path: `modules/hyprland/files/themes/catppuccin/nvim.lua`

```lua
return {
  plugin = {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup({ transparent_background = true })
    end,
  },
  scheme = "catppuccin-mocha",
}
```

- [ ] **Step 2: kanagawa**

Path: `modules/hyprland/files/themes/kanagawa/nvim.lua`

```lua
return {
  plugin = {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup({ transparent = true })
    end,
  },
  scheme = "kanagawa",
}
```

- [ ] **Step 3: tokyo-night**

Path: `modules/hyprland/files/themes/tokyo-night/nvim.lua`

```lua
return {
  plugin = {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ style = "moon", transparent = true })
    end,
  },
  scheme = "tokyonight-moon",
}
```

- [ ] **Step 4: nightfox**

Path: `modules/hyprland/files/themes/nightfox/nvim.lua`

```lua
return {
  plugin = {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("nightfox").setup({ options = { transparent = true } })
    end,
  },
  scheme = "nightfox",
}
```

- [ ] **Step 5: everforest-dark**

Path: `modules/hyprland/files/themes/everforest-dark/nvim.lua`

```lua
return {
  plugin = {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.everforest_background = "hard"
      vim.g.everforest_transparent_background = 1
    end,
  },
  scheme = "everforest",
}
```

- [ ] **Step 6: gruvbox-dark**

Path: `modules/hyprland/files/themes/gruvbox-dark/nvim.lua`

```lua
return {
  plugin = {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      require("gruvbox").setup({ transparent_mode = true })
    end,
  },
  scheme = "gruvbox",
}
```

- [ ] **Step 7: nord-darker**

Path: `modules/hyprland/files/themes/nord-darker/nvim.lua`

```lua
return {
  plugin = {
    "gbprod/nord.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("nord").setup({ transparent = true })
    end,
  },
  scheme = "nord",
}
```

- [ ] **Step 8: e-ink**

Path: `modules/hyprland/files/themes/e-ink/nvim.lua`

```lua
return {
  plugin = {
    "e-ink-colorscheme/e-ink.nvim",
    name = "e-ink",
    lazy = false,
    priority = 1000,
  },
  scheme = "e-ink",
}
```

- [ ] **Step 9: noir**

Path: `modules/hyprland/files/themes/noir/nvim.lua`

```lua
return {
  plugin = {
    "dzfrias/noir.nvim",
    lazy = false,
    priority = 1000,
  },
  scheme = "noir",
}
```

- [ ] **Step 10: Verify all specs parse as Lua**

```bash
for f in modules/hyprland/files/themes/*/nvim.lua; do
  echo "== $f"
  lua5.4 -e "local ok, err = pcall(dofile, '$f'); if not ok then print('FAIL:', err); os.exit(1) end"
done
```

(If `lua5.4` isn't available, `nvim --headless -c "lua dofile(...)" -c "qa"` works too.)

Expected: each file parses, no failures.

- [ ] **Step 11: Commit**

```bash
git add modules/hyprland/files/themes/*/nvim.lua
git commit -m "themes: nvim specs for the remaining 9 static themes"
```

---

## Task 4: Add the matugen nvim template

**Files:**
- Create: `modules/hyprland/files/matugen/templates/nvim-colors.lua`

This template emits a self-contained Neovim colorscheme file. It defines the canonical palette, runs `hi clear` / `colors_name`, and applies highlights via `vim.api.nvim_set_hl`. Keeping highlights in the template (not in nvim's lua dir) means the matugen path is symmetric with static themes — the dispatcher just calls `vim.cmd.colorscheme("matugen")`.

- [ ] **Step 1: Write the template**

Path: `modules/hyprland/files/matugen/templates/nvim-colors.lua`

```lua
-- Generated by matugen. Do not edit by hand.
-- Self-applying Neovim colorscheme using the canonical theme vocabulary.

vim.cmd("hi clear")
if vim.g.syntax_on then vim.cmd("syntax reset") end
vim.g.colors_name = "matugen"

local p = {
  bg0    = "{{colors.surface.default.hex}}",
  bg1    = "{{colors.surface_container_low.default.hex}}",
  bg2    = "{{colors.surface_container.default.hex}}",
  bg3    = "{{colors.surface_container_high.default.hex}}",
  bg4    = "{{colors.surface_container_highest.default.hex}}",
  fg     = "{{colors.on_surface.default.hex}}",
  red    = "{{colors.error.default.hex}}",
  orange = "{{colors.tertiary.default.hex}}",
  yellow = "{{colors.secondary_fixed_dim.default.hex}}",
  green  = "{{colors.primary.default.hex}}",
  aqua   = "{{colors.tertiary_container.default.hex}}",
  blue   = "{{colors.secondary.default.hex}}",
  purple = "{{colors.inverse_primary.default.hex}}",
  grey0  = "{{colors.outline_variant.default.hex}}",
  grey1  = "{{colors.outline.default.hex}}",
  grey2  = "{{colors.on_surface_variant.default.hex}}",
}

local hi = vim.api.nvim_set_hl
local function set(group, opts) hi(0, group, opts) end

-- UI
set("Normal",        { fg = p.fg, bg = p.bg0 })
set("NormalFloat",   { fg = p.fg, bg = p.bg1 })
set("FloatBorder",   { fg = p.bg4, bg = p.bg1 })
set("CursorLine",    { bg = p.bg2 })
set("CursorLineNr",  { fg = p.fg, bold = true })
set("LineNr",        { fg = p.grey1 })
set("SignColumn",    { bg = p.bg0 })
set("VertSplit",     { fg = p.bg4 })
set("WinSeparator",  { fg = p.bg4 })
set("Visual",        { bg = p.bg3 })
set("StatusLine",    { fg = p.fg, bg = p.bg1 })
set("StatusLineNC",  { fg = p.grey1, bg = p.bg1 })
set("Pmenu",         { fg = p.fg, bg = p.bg1 })
set("PmenuSel",      { fg = p.bg0, bg = p.blue })
set("PmenuThumb",    { bg = p.bg3 })
set("MatchParen",    { bg = p.bg3, bold = true })
set("Search",        { fg = p.bg0, bg = p.yellow })
set("IncSearch",     { fg = p.bg0, bg = p.orange })
set("Folded",        { fg = p.grey1, bg = p.bg1 })

-- Syntax
set("Comment",     { fg = p.grey1, italic = true })
set("Identifier",  { fg = p.fg })
set("Function",    { fg = p.green })
set("Statement",   { fg = p.purple })
set("Keyword",     { fg = p.purple })
set("String",      { fg = p.aqua })
set("Number",      { fg = p.orange })
set("Boolean",     { fg = p.orange })
set("Constant",    { fg = p.orange })
set("Type",        { fg = p.yellow })
set("PreProc",     { fg = p.purple })
set("Special",     { fg = p.red })
set("Operator",    { fg = p.fg })
set("Delimiter",   { fg = p.grey2 })
set("Title",       { fg = p.blue, bold = true })

-- Diagnostics
set("DiagnosticError",   { fg = p.red })
set("DiagnosticWarn",    { fg = p.yellow })
set("DiagnosticInfo",    { fg = p.blue })
set("DiagnosticHint",    { fg = p.aqua })
set("DiagnosticOk",      { fg = p.green })

-- Diff / git
set("DiffAdd",     { fg = p.green })
set("DiffChange",  { fg = p.yellow })
set("DiffDelete",  { fg = p.red })
set("GitSignsAdd",    { fg = p.green })
set("GitSignsChange", { fg = p.yellow })
set("GitSignsDelete", { fg = p.red })

-- Treesitter (links)
set("@variable",    { fg = p.fg })
set("@function",    { link = "Function" })
set("@keyword",     { link = "Keyword" })
set("@string",      { link = "String" })
set("@number",      { link = "Number" })
set("@type",        { link = "Type" })
set("@comment",     { link = "Comment" })
set("@operator",    { link = "Operator" })
set("@punctuation", { fg = p.grey2 })
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyprland/files/matugen/templates/nvim-colors.lua
git commit -m "matugen: nvim template — self-applying colorscheme"
```

---

## Task 4b: Add the neovim module gitignore

**Files:**
- Create: `modules/neovim/files/.gitignore`
- Create: `modules/neovim/files/nvim/colors/.gitkeep`

`~/.config/nvim` is symlinked to `modules/neovim/files/nvim/`, so matugen's `output_path = '~/.config/nvim/colors/matugen.lua'` resolves into the dotfiles repo. Without a gitignore, the generated palette would be tracked. Mirrors the existing `modules/hyprland/files/.gitignore` pattern.

- [ ] **Step 1: Create the colors dir + .gitkeep**

```bash
mkdir -p modules/neovim/files/nvim/colors
touch modules/neovim/files/nvim/colors/.gitkeep
```

This guarantees the dir exists on a fresh clone before matugen has run.

- [ ] **Step 2: Write the gitignore**

Path: `modules/neovim/files/.gitignore`

```
nvim/colors/matugen.lua
```

- [ ] **Step 3: Verify**

```bash
git check-ignore -v modules/neovim/files/nvim/colors/matugen.lua
```

Expected: line referencing `modules/neovim/files/.gitignore`.

- [ ] **Step 4: Commit**

```bash
git add modules/neovim/files/.gitignore modules/neovim/files/nvim/colors/.gitkeep
git commit -m "neovim: gitignore generated matugen palette"
```

---

## Task 5: Wire the matugen nvim template into config.toml

**Files:**
- Modify: `modules/hyprland/files/matugen/config.toml`

- [ ] **Step 1: Append the template section**

Append to `modules/hyprland/files/matugen/config.toml`:

```toml
[templates.nvim]
input_path = '~/.config/matugen/templates/nvim-colors.lua'
output_path = '~/.config/nvim/colors/matugen.lua'
post_hook = 'pkill -SIGUSR1 nvim 2>/dev/null || true'
```

The post_hook is intentionally permissive (`|| true`) — when no nvim instances are running, `pkill` exits non-zero and we don't want that to fail the matugen run.

- [ ] **Step 2: Verify by re-running matugen**

```bash
matugen image modules/hyprland/files/wallpapers/default.png
head -20 ~/.config/nvim/colors/matugen.lua
```

Expected: a valid Lua file beginning with `vim.cmd("hi clear")` and a populated `local p = { … }` palette table.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/matugen/config.toml
git commit -m "matugen: emit nvim colorscheme alongside other apps"
```

---

## Task 6: Create the dispatcher (`lua/config/theme.lua`)

**Files:**
- Create: `modules/neovim/files/nvim/lua/config/theme.lua`

- [ ] **Step 1: Write the dispatcher**

Path: `modules/neovim/files/nvim/lua/config/theme.lua`

```lua
local M = {}

local STATE_DIR = vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")
local STATE = STATE_DIR .. "/themes/current"

local THEMES_DIR = vim.fn.expand("~/.config/themes")
local DEFAULT = "rose-pine"

function M.current()
  local f = io.open(STATE, "r")
  if not f then return DEFAULT end
  local name = f:read("*l")
  f:close()
  return (name and name:gsub("%s+$", "")) or DEFAULT
end

function M.list()
  local names = {}
  local handle = vim.uv.fs_scandir(THEMES_DIR)
  if not handle then return names end
  while true do
    local n, t = vim.uv.fs_scandir_next(handle)
    if not n then break end
    if t == "directory" and not n:match("^%.") then
      table.insert(names, n)
    end
  end
  return names
end

local function load_static_spec(name)
  local path = THEMES_DIR .. "/" .. name .. "/nvim.lua"
  local ok, spec = pcall(dofile, path)
  if not ok or type(spec) ~= "table" or not spec.scheme then
    return nil, "missing or invalid nvim.lua for theme '" .. name .. "'"
  end
  return spec
end

local function plugin_id(spec)
  -- lazy.nvim short-name resolution: prefer explicit `name`, else last path segment.
  if type(spec.plugin) == "table" then
    if spec.plugin.name then return spec.plugin.name end
    local repo = spec.plugin[1] or ""
    return repo:match("([^/]+)$") or repo
  end
  return tostring(spec.plugin or "")
end

function M.apply()
  local name = M.current()
  if name == "matugen" then
    local ok = pcall(vim.cmd.colorscheme, "matugen")
    if not ok then
      vim.notify("Theme: matugen palette not yet generated; using default", vim.log.levels.WARN)
      pcall(vim.cmd.colorscheme, "habamax")
    end
    return
  end
  local spec, err = load_static_spec(name)
  if not spec then
    vim.notify("Theme: " .. err, vim.log.levels.WARN)
    return
  end
  local id = plugin_id(spec)
  if id ~= "" then
    pcall(function() require("lazy").load({ plugins = { id } }) end)
  end
  pcall(vim.cmd.colorscheme, spec.scheme)
end

function M.reload()
  M.apply()
  vim.notify("Theme: " .. M.current())
end

return M
```

Notes for reviewers:
- `current()` defaults to `rose-pine` to match the repo-wide default seeded by `install.sh`.
- `apply()` is split: matugen path is `:colorscheme matugen` (the generated file at `~/.config/nvim/colors/matugen.lua` self-applies on source); static path requires the spec, force-loads the lazy plugin (so runtime reloads work even if it wasn't loaded at startup), then sets the colorscheme.
- `reload()` is what the SIGUSR1 autocmd calls.

- [ ] **Step 2: Commit**

```bash
git add modules/neovim/files/nvim/lua/config/theme.lua
git commit -m "nvim: theme dispatcher reads ~/.local/state/themes/current"
```

---

## Task 7: Replace `lua/plugins/colorscheme.lua`

**Files:**
- Modify: `modules/neovim/files/nvim/lua/plugins/colorscheme.lua` (full rewrite)

The current file ships a hand-tuned catppuccin block. Replace it with a list that registers all 10 colorscheme plugins. The active theme's plugin keeps `lazy = false, priority = 1000` (loads eagerly at startup); inactive ones are rewritten to `lazy = true` so lazy.nvim installs them up front but doesn't require them until the dispatcher calls `require("lazy").load(...)` on a runtime switch. (An earlier `cond`-based design was abandoned because `cond = false` skips installation entirely.)

- [ ] **Step 1: Overwrite the file**

Path: `modules/neovim/files/nvim/lua/plugins/colorscheme.lua`

```lua
-- Register every theme's colorscheme plugin so lazy.nvim installs them all up
-- front. The active theme loads eagerly with high priority; the rest stay
-- lazy = true (installed but not required), and the dispatcher force-loads
-- them via `require("lazy").load(...)` on theme switch.

local theme = require("config.theme")
local active = theme.current()

local specs = {}
for _, name in ipairs(theme.list()) do
  if name ~= "matugen" then
    local ok, t = pcall(dofile, vim.fn.expand("~/.config/themes/" .. name .. "/nvim.lua"))
    if ok and type(t) == "table" and type(t.plugin) == "table" then
      local plugin = vim.deepcopy(t.plugin)
      if name ~= active then
        plugin.lazy = true
        plugin.priority = nil
      end
      table.insert(specs, plugin)
    end
  end
end

return specs
```

- [ ] **Step 2: Verify the file is syntactically valid**

```bash
nvim --headless -c "luafile modules/neovim/files/nvim/lua/plugins/colorscheme.lua" -c "qa" 2>&1
```

Expected: no errors. (Won't fully resolve `require("config.theme")` outside the runtimepath but should at least parse.)

- [ ] **Step 3: Commit**

```bash
git add modules/neovim/files/nvim/lua/plugins/colorscheme.lua
git commit -m "nvim: register all theme plugins; gate by active theme"
```

---

## Task 8: Wire the dispatcher into init.lua

**Files:**
- Modify: `modules/neovim/files/nvim/init.lua`
- Modify: `modules/neovim/files/nvim/lua/config/autocmds.lua`

The dispatcher needs to run after `lazy.setup()` (so the active theme's plugin is registered/loaded) and an autocmd needs to handle SIGUSR1.

- [ ] **Step 1: Apply theme after lazy bootstraps**

Append to `modules/neovim/files/nvim/init.lua`:

```lua
require("config.theme").apply()
```

Final init.lua should look like:

```lua
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
require("lsp")
require("config.theme").apply()
```

- [ ] **Step 2: Add the SIGUSR1 autocmd**

Append to `modules/neovim/files/nvim/lua/config/autocmds.lua` (or to wherever existing autocmds live):

```lua
vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1",
  callback = function() require("config.theme").reload() end,
  desc = "Reload theme on external SIGUSR1 (theme-switcher signal)",
})
```

- [ ] **Step 3: Smoke-launch nvim**

```bash
nvim +q
```

Expected: nvim starts cleanly, no errors. Open nvim normally → run `:lua print(require("config.theme").current())` → expect to see the current theme name from state.

- [ ] **Step 4: Commit**

```bash
git add modules/neovim/files/nvim/init.lua modules/neovim/files/nvim/lua/config/autocmds.lua
git commit -m "nvim: apply theme on startup; reload on SIGUSR1"
```

---

## Task 9: Hook nvim into `apply-theme.sh`

**Files:**
- Modify: `modules/hyprland/files/hypr/scripts/apply-theme.sh`

The matugen path already reloads nvim via the `[templates.nvim]` post-hook (Task 5). The static path needs an explicit signal alongside the existing `pkill -SIGUSR2 waybar` etc. block.

- [ ] **Step 1: Add the signal**

Find the static-mode reload block in `apply-theme.sh` (the `else` branch that runs `awww img`, `hyprctl reload`, `pkill -SIGUSR2 waybar`, …). Append:

```bash
  pkill -SIGUSR1 nvim 2>/dev/null || true
```

Place it alongside the other reload signals — order isn't important, but stylistically near the kitty signal makes sense.

- [ ] **Step 2: Sanity-check syntax**

```bash
bash -n modules/hyprland/files/hypr/scripts/apply-theme.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/hyprland/files/hypr/scripts/apply-theme.sh
git commit -m "apply-theme: signal nvim to reload colorscheme"
```

---

## Task 10: End-to-end smoke test

**Files:** none (manual validation)

- [ ] **Step 1: Apply the modules**

```bash
go build -o ./bin/quill ./cmd/quill
./bin/quill apply hyprland neovim
```

Expected: no errors. Symlinks in place.

- [ ] **Step 2: Open nvim cold and verify the active theme renders**

```bash
nvim
```

Expected: nvim opens with the current theme's colorscheme active (rose-pine on a fresh install). Run `:colorscheme` — expect it to print the spec's `scheme` value.

- [ ] **Step 3: Switch theme via Super+D, verify nvim live-reloads**

In a separate terminal, leave nvim open. Press Super+D, pick `gruvbox-dark`. The hyprland theme switches.

In the open nvim, expect colors to swap to gruvbox without restart. If not, check:

```bash
:lua print(require("config.theme").current())
```

If the state file says `gruvbox-dark` but nvim still shows the old colors, the SIGUSR1 autocmd didn't fire — check that the autocmd was actually registered (`:autocmd Signal`).

- [ ] **Step 4: Switch to matugen, verify the generated colorscheme renders**

Super+D → `Matugen (Material You)`. Expected: hypr/waybar/etc. all re-color to matugen. Open nvim — expect matugen colors. Verify the colorscheme file exists:

```bash
head -5 ~/.config/nvim/colors/matugen.lua
```

Expected: starts with `-- Generated by matugen.` and a populated palette.

- [ ] **Step 5: Wallpaper-only change in matugen mode**

Super+Shift+D → pick a different wallpaper. Expected: matugen regenerates, all apps reload, **including nvim** (via the matugen post_hook from Task 5).

- [ ] **Step 6: Idempotency check**

```bash
./bin/quill apply hyprland neovim
```

Expected: no churn — symlinks unchanged, no spurious file rewrites.

- [ ] **Step 7: Cycle through every static theme**

Super+D, pick each theme one at a time. For each:
- Expected: nvim's colors change.
- Note any theme that doesn't render correctly (plugin missing, scheme name wrong, etc.) — fix the corresponding `themes/<name>/nvim.lua` and commit a follow-up.

- [ ] **Step 8: Final commit (only if smoke-test surfaced fixes)**

If any per-theme spec needed adjustment, commit each fix with a descriptive message.

---

## Follow-up work (not in this plan)

- Per-theme custom_highlights — the user dropped the catppuccin block as part of this work. Revisit if any theme feels rough after living with defaults; add tuning back inside the theme's `setup` callback in its `nvim.lua`, or in a `post = function() ... end` hook for highlights that should run after `:colorscheme` applies.
- Refine the matugen highlight set — the template ships a minimal viable group. Common additions: telescope, snacks, gitsigns numhl, which-key, todo-comments. Add inline in `nvim-colors.lua`.
- Cache the dispatcher's state read — `M.current()` does a synchronous file read on every call; if that becomes hot, memoize and invalidate on `Signal`.
- Extract a shared `lua/config/theme_helpers.lua` if `post` hooks across themes start repeating the same patterns (e.g. `clear_bg` for `LineNr` / `NvimTree*` / `SignColumn`). Today kanagawa and tokyo-night each duplicate the helper inline — one more theme with the same shape and the duplication earns a refactor.
