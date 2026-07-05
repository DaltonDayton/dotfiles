return {
  plugin = {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("nightfox").setup({
        options = {
          transparent = true,
          styles = { comments = "italic" },
        },
      })
    end,
  },
  scheme = "nightfox",
  post = function()
    -- default WinSeparator is darker than bg: invisible splits
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#39506d" })
  end,
}
