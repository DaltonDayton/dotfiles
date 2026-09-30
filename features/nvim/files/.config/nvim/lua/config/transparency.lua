-- Strip the background off the groups that paint a solid panel, so the
-- terminal's own background shows through. Ported from Omarchy's
-- plugin/after/transparency.lua; re-applied after every colorscheme change,
-- since setting a colorscheme redefines these groups from scratch.
local M = {}

local GROUPS = {
  -- editor surfaces
  "Normal",
  "NormalNC",
  "NormalFloat",
  "FloatBorder",
  "Pmenu",
  "Terminal",
  "EndOfBuffer",
  "FoldColumn",
  "Folded",
  "SignColumn",
  "LineNr",
  "CursorLineNr",
  "WhichKeyFloat",
  -- telescope
  "TelescopeBorder",
  "TelescopeNormal",
  "TelescopePromptBorder",
  "TelescopePromptTitle",
  -- neo-tree
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "NeoTreeVertSplit",
  "NeoTreeWinSeparator",
  "NeoTreeEndOfBuffer",
  -- nvim-tree
  "NvimTreeNormal",
  "NvimTreeVertSplit",
  "NvimTreeEndOfBuffer",
  -- notify
  "NotifyINFOBody",
  "NotifyERRORBody",
  "NotifyWARNBody",
  "NotifyTRACEBody",
  "NotifyDEBUGBody",
  "NotifyINFOTitle",
  "NotifyERRORTitle",
  "NotifyWARNTitle",
  "NotifyTRACETitle",
  "NotifyDEBUGTitle",
  "NotifyINFOBorder",
  "NotifyERRORBorder",
  "NotifyWARNBorder",
  "NotifyTRACEBorder",
  "NotifyDEBUGBorder",
}

function M.apply()
  for _, name in ipairs(GROUPS) do
    -- link = false so the resolved attributes are read and rewritten onto the
    -- group itself; clearing bg on a link would be a no-op.
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok then
      hl.bg = nil
      pcall(vim.api.nvim_set_hl, 0, name, hl)
    end
  end
end

return M
