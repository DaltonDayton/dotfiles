return {
  plugin = {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        variant = "moon",
        styles = { transparency = true },
      })
    end,
  },
  scheme = "rose-pine-moon",
}
