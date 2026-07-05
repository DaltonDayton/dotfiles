return {
  plugin = {
    "dzfrias/noir.nvim",
    lazy = false,
    priority = 1000,
  },
  scheme = "noir",
  post = function()
    -- noir.nvim has no options; normalize to match the other themes:
    -- transparency, visible separators/borders/comments, defined PmenuSel.
    local set = vim.api.nvim_set_hl
    set(0, "Normal", { fg = "#a0a4a8" })
    set(0, "NormalNC", { fg = "#a0a4a8" })
    set(0, "SignColumn", {})
    set(0, "WinSeparator", { fg = "#3c4043" })
    set(0, "FloatBorder", { fg = "#5f6368", bg = "#0d0b0a" })
    set(0, "PmenuSel", { fg = "#e0e2ea", bg = "#4f5258" })
    set(0, "Comment", { fg = "#5f6368", italic = true })
  end,
}
