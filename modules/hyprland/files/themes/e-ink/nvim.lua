return {
  plugin = {
    "e-ink-colorscheme/e-ink.nvim",
    name = "e-ink",
    lazy = false,
    priority = 1000,
  },
  scheme = "e-ink",
  background = "light",
  post = function()
    -- let kitty's paper background (#e6e6e6, opaque) show through
    vim.api.nvim_set_hl(0, "Normal", { fg = "#5e5e5e" })
    -- e-ink.nvim leaves PmenuSel undefined: invisible completion selection
    vim.api.nvim_set_hl(0, "PmenuSel", { fg = "#0a0a0a", bg = "#aeaeae" })
  end,
}
