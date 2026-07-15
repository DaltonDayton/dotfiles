local M = {}

local STATE_DIR = vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")
local STATE = STATE_DIR .. "/themes/current"

local THEMES_DIR = vim.fn.expand("~/.config/themes")
local DEFAULT = "rose-pine"

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

function M.current()
  local f = io.open(STATE, "r")
  if not f then return DEFAULT end
  local name = f:read("*l")
  f:close()
  return (name and name:gsub("%s+$", "")) or DEFAULT
end

function M.themed_host()
  return vim.uv.fs_stat(THEMES_DIR) ~= nil
end

function M.fallback_spec()
  return vim.deepcopy(FALLBACK)
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
  if type(spec.plugin) == "table" then
    if spec.plugin.name then return spec.plugin.name end
    local repo = spec.plugin[1] or ""
    return repo:match("([^/]+)$") or repo
  end
  return tostring(spec.plugin or "")
end

-- Groups some colorschemes leave undefined; `default = true` yields to any
-- theme (or plugin) that does define them.
local function normalize()
  vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { link = "NonText", default = true })
end

function M.apply()
  if not M.themed_host() then
    pcall(function() require("lazy").load({ plugins = { "catppuccin" } }) end)
    vim.o.background = "dark"
    pcall(vim.cmd.colorscheme, FALLBACK.scheme)
    normalize()
    return
  end
  local name = M.current()
  if name == "matugen" then
    -- dofile() (not :colorscheme matugen) so wallpaper changes that regenerate
    -- the palette while matugen is already active still re-apply. :colorscheme
    -- is a no-op when the scheme is already current.
    local matugen_file = vim.fn.expand("~/.config/nvim/colors/matugen.lua")
    vim.o.background = "dark" -- matugen runs with --prefer darkness
    if vim.uv.fs_stat(matugen_file) then
      pcall(dofile, matugen_file)
    else
      vim.notify("Theme: matugen palette not yet generated; using default", vim.log.levels.WARN)
      pcall(vim.cmd.colorscheme, "habamax")
    end
    normalize()
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
  -- Set before :colorscheme so variant-aware schemes (e-ink) pick the right
  -- side, and so switching away from a light theme resets to dark.
  vim.o.background = spec.background or "dark"
  pcall(vim.cmd.colorscheme, spec.scheme)
  if type(spec.post) == "function" then
    pcall(spec.post)
  end
  normalize()
end

function M.reload()
  M.apply()
  vim.notify("Theme: " .. M.current())
end

return M
