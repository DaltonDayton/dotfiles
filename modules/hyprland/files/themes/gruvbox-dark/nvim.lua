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
}
