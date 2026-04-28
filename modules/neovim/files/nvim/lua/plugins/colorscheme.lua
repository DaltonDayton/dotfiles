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
