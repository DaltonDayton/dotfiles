return {
  plugin = {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      require("gruvbox").setup({ transparent_mode = true })
    end,
  },
  scheme = "gruvbox",
  post = function()
    -- gruvbox links FloatBorder to NormalFloat: borders in bright normal fg
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#665c54" })
    -- gruvbox's `hi clear` leaves BlinkCmpMenuSelection cleared-but-existing,
    -- so blink's default-link to PmenuSel never re-applies: selection invisible
    vim.api.nvim_set_hl(0, "BlinkCmpMenuSelection", { link = "PmenuSel" })
  end,
}
