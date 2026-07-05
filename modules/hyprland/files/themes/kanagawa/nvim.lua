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
  post = function()
    local function clear_bg(group)
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, group, hl)
    end
    for _, g in ipairs({ "LineNr", "LineNrAbove", "LineNrBelow", "CursorLineNr", "SignColumn" }) do
      clear_bg(g)
    end
    -- default WinSeparator is darker than bg: invisible splits
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#54546d" })
  end,
}
