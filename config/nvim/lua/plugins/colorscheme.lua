-- Register every theme's colorscheme plugin so lazy.nvim installs them all up
-- front. The active theme loads eagerly with high priority; the rest stay
-- lazy = true (installed but not required), and the dispatcher force-loads
-- them via `require("lazy").load(...)` on theme switch.

local theme = require("config.theme")

-- No theme-switcher host (no ~/.config/themes): install just catppuccin so the
-- dispatcher's fallback in config/theme.lua has a colorscheme to load.
-- fallback_spec() returns the theme wrapper { plugin = {...}, scheme = ... };
-- this file returns lazy *plugin* specs, so hand lazy the inner .plugin.
if not theme.themed_host() then
  return { theme.fallback_spec().plugin }
end

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
