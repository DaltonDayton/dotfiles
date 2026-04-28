return {
  plugin = {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ style = "moon", transparent = true })
    end,
  },
  scheme = "tokyonight-moon",
}
