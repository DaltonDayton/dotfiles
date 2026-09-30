-- Omarchy owns the colorscheme.
--
-- `omarchy theme set <name>` re-stages ~/.local/state/omarchy/current/theme/,
-- and that directory's neovim.lua is a lazy.nvim spec for the theme: the
-- colorscheme plugin, plus a LazyVim entry carrying the colorscheme name.
-- Omarchy 4 generates most of them from default/themed/neovim.lua.tpl as
-- bjarneo/aether.nvim with the theme's palette in `opts`; a handful of themes
-- ship a hand-written neovim.lua naming their own plugin instead.
--
-- Upstream symlinks that file to lua/plugins/theme.lua and lets lazy's change
-- detection notice the swap. Neither half of that works here:
--
--   * This config isn't LazyVim. Importing the spec as-is would have lazy
--     install LazyVim and, since the entry carries `opts` and no `config`,
--     call require("lazyvim").setup() -- a whole distro landing on top of this
--     one. The entry is read for its colorscheme name and then dropped.
--   * ~/.config/nvim is a symlink into a git repo, so upstream's relative
--     symlink would resolve against the repo rather than $HOME, and an
--     absolute one would commit a hardcoded /home/<user> path. The spec is
--     read from its real path instead, and a watcher on the staging directory
--     stands in for lazy's change detection.

local M = {}

local CURRENT = vim.fn.expand("~/.local/state/omarchy/current")
local SPEC = CURRENT .. "/theme/neovim.lua"

-- The colorscheme to fall back to when there is no staged Omarchy theme (a
-- non-Omarchy host, or a first boot before any theme is applied). Built in, so
-- it needs no plugin.
local FALLBACK = "habamax"

---Read the staged spec.
---@return table[]|nil plugins  colorscheme plugin specs, active one first
---@return string|nil scheme    colorscheme to activate
local function read_spec()
  local ok, spec = pcall(dofile, SPEC)
  if not ok or type(spec) ~= "table" then
    return nil, nil
  end

  local plugins, scheme = {}, nil
  for _, entry in ipairs(spec) do
    if type(entry) == "table" and type(entry[1]) == "string" then
      if entry[1] == "LazyVim/LazyVim" then
        scheme = (entry.opts and entry.opts.colorscheme) or scheme
      else
        table.insert(plugins, entry)
      end
    end
  end

  if not scheme or #plugins == 0 then
    return nil, nil
  end
  return plugins, scheme
end

-- lazy keys Config.plugins by the spec's `name`, falling back to the last
-- segment of the url -- so "folke/tokyonight.nvim" is "tokyonight.nvim", not
-- the full repo path.
local function plugin_key(plugin)
  return plugin.name or plugin[1]:match("[^/]+$")
end

-- Groups some colorschemes leave undefined; `default = true` yields to any
-- theme (or plugin) that does define them.
local function normalize()
  vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { link = "NonText", default = true })
end

local function activate(scheme)
  pcall(vim.cmd.colorscheme, scheme)
  require("config.transparency").apply()
  normalize()
end

---The active theme's plugin spec, for lua/plugins/colorscheme.lua.
---@return table[]
function M.plugins()
  local plugins = read_spec()
  if not plugins then
    return {}
  end

  local out = {}
  for _, plugin in ipairs(plugins) do
    plugin = vim.deepcopy(plugin)
    plugin.lazy = false -- the colorscheme has to be up before anything draws
    plugin.priority = 1000
    table.insert(out, plugin)
  end
  return out
end

---Apply the staged theme. lazy has already loaded the plugin by this point
---(lua/plugins/colorscheme.lua marks it lazy = false); this sets the scheme.
function M.apply()
  local plugins, scheme = read_spec()
  if not scheme then
    activate(FALLBACK)
    return
  end

  pcall(function()
    require("lazy").load({ plugins = { plugin_key(plugins[1]) } })
  end)
  activate(scheme)
end

---Swap to the newly staged theme without restarting.
function M.reload()
  local plugins, scheme = read_spec()
  if not scheme then
    return
  end

  local Config = require("lazy.core.config")
  local Loader = require("lazy.core.loader")
  local plugin = Config.plugins[plugin_key(plugins[1])]

  -- Clear first, so a group the outgoing theme defined and the incoming one
  -- doesn't can't survive the swap.
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end
  -- A light theme sets this itself; reset so switching away from one restores.
  vim.o.background = "dark"

  if plugin then
    -- Two aether-based themes are the same plugin with a different palette, and
    -- lazy caches both the resolved opts and the plugin's own lua modules, so
    -- neither would pick up the new colours on their own. Hand the new opts over
    -- as a function, which discards the inherited value rather than merging the
    -- outgoing palette underneath it, then drop both caches.
    if plugins[1].opts then
      local opts = plugins[1].opts
      plugin.opts = function()
        return vim.deepcopy(opts)
      end
      plugin._.cache = nil
    end

    require("lazy.core.util").walkmods(plugin.dir .. "/lua", function(modname)
      package.loaded[modname] = nil
      package.preload[modname] = nil
    end)

    if plugin._.loaded then
      Loader.reload(plugin) -- re-runs config with the opts set above
    else
      Loader.colorscheme(scheme)
    end
  else
    Loader.colorscheme(scheme)
  end

  activate(scheme)
  vim.cmd("redraw!")
  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
end

---Watch for `omarchy theme set`.
---
---It stages into current/next-theme and finishes with `rm -rf current/theme &&
---mv next-theme theme`, so neovim.lua's inode is replaced wholesale -- an
---fs_event on the file itself would be left watching the deleted one. Watch
---current/, which survives, and debounce the burst of events one swap produces.
function M.watch()
  if not vim.uv.fs_stat(CURRENT) then
    return
  end

  local handle = vim.uv.new_fs_event()
  local timer = vim.uv.new_timer()
  if not handle or not timer then
    return
  end

  local ok = pcall(function()
    assert(handle:start(CURRENT, {}, function()
      timer:stop()
      timer:start(150, 0, vim.schedule_wrap(function()
        M.reload()
      end))
    end))
  end)

  if not ok then
    handle:close()
    timer:close()
  end
end

function M.setup()
  M.apply()
  M.watch()
end

return M
