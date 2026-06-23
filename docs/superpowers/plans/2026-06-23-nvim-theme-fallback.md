# Neovim catppuccin Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When `~/.config/themes` is absent (non-Hyprland host, e.g. WSL), neovim defaults to catppuccin-mocha (transparent) instead of failing to set any colorscheme — additively, the Arch/Hyprland path unchanged.

**Architecture:** Two coupled edits in the neovim module. `lua/config/theme.lua` gains a single `FALLBACK` spec (reused verbatim from the hyprland catppuccin fragment) plus `M.themed_host()` and `M.fallback_spec()` helpers, and a guard at the top of `M.apply()`. `lua/plugins/colorscheme.lua` short-circuits to register the catppuccin plugin when not on a themed host (today it returns `{}` there). The themes-dir-presence check is the discriminator and covers both startup (`init.lua`) and SIGUSR1 reload (`autocmds.lua` → `M.reload()` → `M.apply()`).

**Tech Stack:** Lua (neovim config), lazy.nvim plugin specs. **No Go changes.** Verification is headless-nvim assertions + a live nvim check.

## Global Constraints

- Additive only: on a themed host (`~/.config/themes` exists, i.e. Arch+Hyprland) behavior is byte-for-byte unchanged — the fallback branch must not run.
- Discriminator is `vim.uv.fs_stat(THEMES_DIR) ~= nil` (themes-dir presence). Do NOT use `$QUILL_OS` or `$HYPRLAND_INSTANCE_SIGNATURE`.
- Fallback is catppuccin **mocha**, **transparent** (`scheme = "catppuccin-mocha"`, `transparent_background = true`) — identical to `modules/hyprland/files/themes/catppuccin/nvim.lua`.
- DRY: the catppuccin spec is defined **once** in `theme.lua` and consumed by `colorscheme.lua` via `theme.fallback_spec()`. Do not duplicate the literal in both files.
- Touch only the neovim module. Do NOT modify the hyprland module or its theme fragments.

**Branch:** `nvim-theme-fallback` (off `startover`, already checked out). Repo-local git identity already set.

**Spec:** `docs/superpowers/specs/2026-06-23-nvim-theme-fallback-design.md`.

> **Shell note:** in this repo's zsh, `cd` is aliased to zoxide and bare globs can trip `set -e`. Use absolute paths and `git -C /home/dalton/.dotfiles ...`. Avoid `cd module/...`.

---

## File structure

| File | Change | Task |
|---|---|---|
| `modules/neovim/files/nvim/lua/config/theme.lua` | add `FALLBACK` const + `M.themed_host()` + `M.fallback_spec()`; guard at top of `M.apply()` | 1 |
| `modules/neovim/files/nvim/lua/plugins/colorscheme.lua` | short-circuit to `{ theme.fallback_spec() }` when not a themed host | 1 |

Single task — the two edits are tightly coupled (`colorscheme.lua` consumes the
helpers `theme.lua` defines) and must ship together to work.

---

## Task 1: catppuccin fallback when themes dir absent

**Files:**
- Modify: `modules/neovim/files/nvim/lua/config/theme.lua`
- Modify: `modules/neovim/files/nvim/lua/plugins/colorscheme.lua`

**Interfaces:**
- Consumes: existing `theme.lua` module table `M`, `THEMES_DIR` local
  (`vim.fn.expand("~/.config/themes")`), existing `M.current()` / `M.apply()` /
  `M.reload()`.
- Produces: `M.themed_host() -> boolean` (true iff `~/.config/themes` exists),
  `M.fallback_spec() -> table` (a deepcopy of the catppuccin lazy spec:
  `{ plugin = {...}, scheme = "catppuccin-mocha" }`). `colorscheme.lua` calls
  both.

- [ ] **Step 1: Read the two current files**

Run:
```bash
sed -n '1,20p' /home/dalton/.dotfiles/modules/neovim/files/nvim/lua/config/theme.lua
cat /home/dalton/.dotfiles/modules/neovim/files/nvim/lua/plugins/colorscheme.lua
```
Confirm `theme.lua` opens with `local M = {}`, then (line 6) `local THEMES_DIR =
vim.fn.expand("~/.config/themes")` and (line 7) `local DEFAULT = "rose-pine"`.
Confirm `colorscheme.lua` has `local theme = require("config.theme")` followed by
`local active = theme.current()`, then a `for _, name in ipairs(theme.list())`
loop, and `return specs` at the end.

- [ ] **Step 2: Add the FALLBACK spec to theme.lua**

In `modules/neovim/files/nvim/lua/config/theme.lua`, immediately after the
`local DEFAULT = "rose-pine"` line (line 7), insert:

```lua

-- Default colorscheme when there is no theme-switcher host (no ~/.config/themes,
-- e.g. WSL/non-Hyprland). Mirrors modules/hyprland/files/themes/catppuccin/nvim.lua.
local FALLBACK = {
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

- [ ] **Step 3: Add the two helper functions to theme.lua**

In the same file, immediately after the end of `function M.current() ... end`
(the block that returns `DEFAULT`), insert:

```lua

function M.themed_host()
  return vim.uv.fs_stat(THEMES_DIR) ~= nil
end

function M.fallback_spec()
  return vim.deepcopy(FALLBACK)
end
```

- [ ] **Step 4: Add the fallback guard at the top of M.apply()**

In the same file, find `function M.apply()` and insert the guard as the very
first statements inside it, before the existing `local name = M.current()` line:

```lua
function M.apply()
  if not M.themed_host() then
    pcall(function() require("lazy").load({ plugins = { "catppuccin" } }) end)
    pcall(vim.cmd.colorscheme, FALLBACK.scheme)
    return
  end
  local name = M.current()
```

Leave the rest of `M.apply()` (the matugen branch, `load_static_spec`, etc.)
exactly as-is.

- [ ] **Step 5: Short-circuit colorscheme.lua when not a themed host**

In `modules/neovim/files/nvim/lua/plugins/colorscheme.lua`, insert the
short-circuit immediately after the `local theme = require("config.theme")` line
and BEFORE the `local active = theme.current()` line:

```lua
local theme = require("config.theme")

-- No theme-switcher host (no ~/.config/themes): install just catppuccin so the
-- dispatcher's fallback in config/theme.lua has a colorscheme to load.
-- fallback_spec() returns the theme wrapper { plugin = {...}, scheme = ... };
-- this file returns lazy *plugin* specs, so hand lazy the inner .plugin.
if not theme.themed_host() then
  return { theme.fallback_spec().plugin }
end

local active = theme.current()
```

Leave the rest of the file (the `for ... ipairs(theme.list())` loop and `return
specs`) unchanged.

- [ ] **Step 6: Headless load + syntax check**

Run:
```bash
nvim --headless "+lua require('config.theme')" +qa 2>&1
```
Expected: no Lua error output (a syntax/typo error would print a stack trace
here). Clean exit.

- [ ] **Step 7: Assert themed_host() is false on this box**

This box (WSL) has no `~/.config/themes`, so the helper must return false:

```bash
nvim --headless "+lua assert(require('config.theme').themed_host() == false, 'themed_host should be false on WSL')" "+lua print('themed_host OK')" +qa 2>&1
```
Expected: prints `themed_host OK`, no assertion error.

- [ ] **Step 8: Assert fallback_spec() shape**

```bash
nvim --headless "+lua local s = require('config.theme').fallback_spec(); assert(s.scheme == 'catppuccin-mocha', 'scheme'); assert(s.plugin[1] == 'catppuccin/nvim', 'repo'); print('fallback_spec OK')" +qa 2>&1
```
Expected: prints `fallback_spec OK`, no assertion error.

- [ ] **Step 9: Live check — catppuccin actually applies**

Open nvim normally (`nvim`), let lazy install `catppuccin` on first launch
(`:Lazy sync` if it does not auto-install), then run inside nvim:
```
:lua print(vim.g.colors_name)
```
Expected: `catppuccin-mocha`. Also `:Lazy` shows `catppuccin` loaded, and there
is no `Theme: ...` WARN in `:messages`, and the scheme is not `habamax`.

(This step needs a real TTY/lazy install; if running as an automated implementer
without one, do Steps 6–8 and note that Step 9 is left for the human.)

- [ ] **Step 10: Commit**

```bash
git -C /home/dalton/.dotfiles add modules/neovim/files/nvim/lua/config/theme.lua modules/neovim/files/nvim/lua/plugins/colorscheme.lua
git -C /home/dalton/.dotfiles commit -m "neovim: default to catppuccin when no theme-switcher host (non-Hyprland)"
```

---

## Done criteria

- [ ] `theme.lua` defines `FALLBACK` once, plus `M.themed_host()` and `M.fallback_spec()`; `M.apply()` has the themed-host guard as its first statements.
- [ ] `colorscheme.lua` returns `{ theme.fallback_spec().plugin }` when `not theme.themed_host()`, before any use of `theme.current()`/`theme.list()` (returns the inner lazy plugin spec, not the wrapper).
- [ ] No duplication of the catppuccin literal — `colorscheme.lua` uses `theme.fallback_spec()`.
- [ ] Headless checks (Steps 6–8) pass: module loads, `themed_host()` is false here, `fallback_spec()` has scheme `catppuccin-mocha` and repo `catppuccin/nvim`.
- [ ] Live (Step 9, human): nvim opens on `catppuccin-mocha`, catppuccin installed, no WARN, not habamax.
- [ ] Arch/themed-host path unchanged: when `~/.config/themes` exists, `themed_host()` is true, `apply()` takes the existing branch, `colorscheme.lua` builds specs dynamically as before.
- [ ] Only the two neovim-module files changed. Hyprland module untouched.

## Human verification (post-merge)

- On this WSL box: open nvim → catppuccin-mocha, transparent bg.
- SIGUSR1 path: `:lua require('config.theme').reload()` → re-applies catppuccin, no error.
- (If available) on an Arch+Hyprland box: theme switching still works, fallback never fires.
