return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    main = "render-markdown",
    opts = {
      file_types = { "markdown", "codecompanion" }, -- also render the CodeCompanion chat buffer
      ignore = function()
        local path = vim.fn.expand("%:p")
        local vaults = vim.fn.expand("~") .. "/vaults/"
        return vim.startswith(path, vaults)
      end,
    },
    name = "render-markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
  },
}
