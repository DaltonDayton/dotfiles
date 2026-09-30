-- Every colorscheme Omarchy can switch to, installed up front but not loaded,
-- so `omarchy theme set` never has to clone anything mid-session. The staged
-- theme's own spec (see lua/config/theme.lua) replaces its entry below, which
-- is what carries the palette and makes it load eagerly.
local theme = require("config.theme")

local catalogue = {
  -- Name and branch must match Omarchy's generated theme spec
  -- (default/themed/neovim.lua.tpl). lazy merges specs by url and lets an
  -- explicit name rename the merged plugin, so a bare "bjarneo/aether.nvim"
  -- here would build the cache into lazy/aether.nvim while the generated spec
  -- renames it to lazy/aether at runtime -- a directory that was never cloned.
  { "bjarneo/aether.nvim", branch = "v3", name = "aether" },
  { "bjarneo/ethereal.nvim" },
  { "bjarneo/hackerman.nvim" },
  { "bjarneo/vantablack.nvim" },
  { "bjarneo/white.nvim" },
  { "catppuccin/nvim", name = "catppuccin" },
  { "EdenEast/nightfox.nvim" },
  { "ellisonleao/gruvbox.nvim" },
  { "ficcdaf/ashen.nvim" },
  { "folke/tokyonight.nvim" },
  { "kepano/flexoki-neovim" },
  { "neanias/everforest-nvim" },
  { "OldJobobo/miasma.nvim" },
  { "OldJobobo/retro-82.nvim" },
  { "omacom-io/lumon.nvim" },
  { "rebelot/kanagawa.nvim" },
  { "ribru17/bamboo.nvim" },
  { "rose-pine/neovim", name = "rose-pine" },
  { "tahayvr/matteblack.nvim" },
}

for _, plugin in ipairs(catalogue) do
  plugin.lazy = true
  plugin.priority = 1000
end

-- Swap in the active theme's spec rather than letting lazy merge a lazy = true
-- and a lazy = false copy of the same url -- one spec per plugin, no reliance
-- on which import order wins.
local by_url = {}
for i, plugin in ipairs(catalogue) do
  by_url[plugin[1]] = i
end

for _, plugin in ipairs(theme.plugins()) do
  local i = by_url[plugin[1]]
  if i then
    catalogue[i] = plugin
  else
    table.insert(catalogue, plugin)
  end
end

return catalogue
