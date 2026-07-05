return {
  plugin = {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        variant = "main",
        styles = { transparency = true },
      })
    end,
  },
  scheme = "rose-pine-main",
  post = function()
    -- transparency style clears floats entirely; give them a panel like catppuccin
    vim.api.nvim_set_hl(0, "NormalFloat", { fg = "#e0def4", bg = "#1f1d2e" })
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#6e6a86", bg = "#1f1d2e" })
  end,
}
