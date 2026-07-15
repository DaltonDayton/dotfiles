return {
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
  post = function()
    -- transparent_background leaves floats on a darker panel; clear to match panes
    local function clear_bg(group)
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, group, hl)
    end
    for _, g in ipairs({ "NormalFloat", "FloatBorder", "FloatTitle" }) do clear_bg(g) end
  end,
}
