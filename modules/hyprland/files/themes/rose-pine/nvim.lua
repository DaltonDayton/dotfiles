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
}
