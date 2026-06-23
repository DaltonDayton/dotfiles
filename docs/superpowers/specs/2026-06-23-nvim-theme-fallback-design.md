# Spec: Neovim catppuccin fallback outside Hyprland

**Date:** 2026-06-23
**Status:** Draft (pending review)

## Problem

The neovim theme dispatcher (`modules/neovim/files/nvim/lua/config/theme.lua`)
is built for the Hyprland theme-switcher. At startup `init.lua` calls
`require("config.theme").apply()`, which:

1. reads the active theme name from the state file `~/.local/state/themes/current`
   (default `rose-pine` if absent), then
2. `dofile`s the per-theme spec `~/.config/themes/<name>/nvim.lua`, force-loads
   that lazy plugin, and sets its colorscheme.

Both `~/.config/themes` (a symlink) and the state file are created **only** by
the `hyprland` module (`modules/hyprland/module.toml` symlink + `install.sh`
seed). On WSL/Ubuntu — where Hyprland isn't installed — neither exists, so:

- `M.current()` returns `rose-pine` (state file absent),
- `load_static_spec("rose-pine")` fails (`~/.config/themes/rose-pine/nvim.lua`
  absent),
- `apply()` emits a `WARN` and returns **without setting any colorscheme**.

nvim ends up on lazy's bootstrap fallback `habamax`. Worse, the colorscheme
plugin list (`lua/plugins/colorscheme.lua`) is built by iterating
`theme.list()`, which is empty on WSL — so **no colorscheme plugin is installed
at all**, and catppuccin is only declared inside the hyprland module's theme
fragment (`modules/hyprland/files/themes/catppuccin/nvim.lua`), unreachable on
WSL.

**Desired:** when not on a theme-switcher host, neovim defaults to catppuccin
(mocha, transparent background).

## Guiding principle: additive, Arch path untouched

Same contract as the WSL/Ubuntu slices. On Arch the `~/.config/themes` symlink
exists, so the fallback branch never fires and the existing theme-switcher flow
is byte-for-byte unchanged. The fix lives entirely in the **neovim** module
(cross-platform), not hyprland.

## Discriminator: presence of `~/.config/themes`

The robust "am I on a theme-switcher host?" signal available to Lua at runtime is
the existence of the themes directory: `vim.uv.fs_stat(THEMES_DIR) ~= nil`. This:

- reuses the indirection that already exists (no new env var plumbing),
- is correct for the real distinction (theme **system installed** vs not) rather
  than "is Hyprland running right now" — an Arch box in a TTY or over SSH still
  has the themes dir and its colorschemes, so it should keep using them,
- naturally covers both startup (`init.lua`) and SIGUSR1 reload (`autocmds.lua`
  → `M.reload()` → `M.apply()`).

`$QUILL_OS` is rejected: the Go runner exports it only to install.sh
subprocesses, not into the interactive/nvim environment.
`$HYPRLAND_INSTANCE_SIGNATURE` is rejected: it tracks "Hyprland running now", not
"theme system installed", and would wrongly drop an Arch TTY session to
catppuccin.

## Changes (neovim module only)

### `lua/config/theme.lua`

Define the fallback spec **once** (reused verbatim from the hyprland catppuccin
fragment — mocha, transparent), and expose two helpers so `colorscheme.lua`
shares the same source of truth (DRY):

```lua
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

function M.themed_host()
  return vim.uv.fs_stat(THEMES_DIR) ~= nil
end

function M.fallback_spec()
  return vim.deepcopy(FALLBACK)
end
```

Guard at the top of `M.apply()` (before the existing matugen/static logic):

```lua
function M.apply()
  if not M.themed_host() then
    pcall(function() require("lazy").load({ plugins = { "catppuccin" } }) end)
    pcall(vim.cmd.colorscheme, FALLBACK.scheme)
    return
  end
  -- ... existing matugen + static-spec logic unchanged ...
end
```

### `lua/plugins/colorscheme.lua`

Short-circuit when not on a themed host so lazy actually installs catppuccin
(today this file returns `{}` on WSL):

```lua
local theme = require("config.theme")

if not theme.themed_host() then
  return { theme.fallback_spec() }
end

-- ... existing dynamic spec-building loop unchanged ...
```

## Why reuse the exact hyprland catppuccin fragment

The hyprland module already ships `catppuccin/nvim` with
`transparent_background = true` and scheme `catppuccin-mocha`
(`modules/hyprland/files/themes/catppuccin/nvim.lua`). The user chose mocha +
transparent, which is identical — so the fallback is the same plugin/config,
just reached via a different (themes-dir-absent) path. lazy dedupes by repo, so
even if both the hyprland theme fragment and this fallback declare
`catppuccin/nvim` on some hypothetical host, there is no conflict.

## Testing / verification

No Go changes → no Go unit tests. Lua is verified live:

- **WSL (this box, no themes dir):** launch nvim. `:colorscheme` reports
  `catppuccin-mocha`; `:lua print(require("config.theme").themed_host())` prints
  `false`; `:Lazy` shows `catppuccin` installed and loaded. No `Theme: ...` WARN,
  not on `habamax`.
- **Reload path:** `:lua require("config.theme").reload()` re-applies catppuccin
  without error (proves the SIGUSR1 path works).
- **Arch (themed host) regression:** on a box with `~/.config/themes`,
  `themed_host()` returns `true`, `apply()` takes the existing branch, and the
  colorscheme list builds dynamically exactly as before — fallback never runs.
- `:checkhealth` / `:messages` clean (no stack traces from the new code).

## Scope boundaries

**In scope:** neovim defaults to catppuccin-mocha (transparent) when
`~/.config/themes` is absent; catppuccin plugin installed in that case; reload
path covered.

**Out of scope:**

- Any theme-switcher / matugen behavior on WSL (there is no Hyprland, no Super+D
  cycling — the fallback is a static default, not a switchable theme set).
- Making catppuccin switchable on WSL or adding a WSL theme picker.
- Touching the hyprland module or its theme fragments.

**Permanent out of scope (unchanged):** macOS / other distros; secrets; `quill
remove`.

## Open questions

None. Flavor (mocha), transparency (transparent), and discriminator
(themes-dir presence) all resolved during brainstorming.
