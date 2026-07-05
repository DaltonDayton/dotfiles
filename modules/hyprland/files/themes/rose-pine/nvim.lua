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
    -- keep floats transparent; just give them a visible muted border
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#6e6a86" })
  end,
}
