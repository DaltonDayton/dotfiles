return {
  plugin = {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ style = "night", transparent = true })
    end,
  },
  scheme = "tokyonight-night",
  post = function()
    local function clear_bg(group)
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, group, hl)
    end
    for _, g in ipairs({
      "NvimTreeNormal", "NvimTreeNormalNC", "NvimTreeNormalFloat",
      "NvimTreeEndOfBuffer", "NvimTreeWinSeparator",
      "NvimTreeStatusLine", "NvimTreeStatusLineNC",
    }) do
      clear_bg(g)
    end
    -- default WinSeparator is darker than bg: invisible splits
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#545c7e" })
  end,
}
