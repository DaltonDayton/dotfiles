return {
  {
    "OXY2DEV/markview.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    config = function()
      require("markview").setup({
        preview = {
          filetypes = { "markdown" },
          condition = function(buf)
            -- return false skips a buffer, nil falls through to the filetypes allowlist.
            -- Only force-skip inside the vaults dir; let everything else use normal gating
            -- (returning true here would force-attach to NvimTree/pickers and crash treesitter).
            local path = vim.api.nvim_buf_get_name(buf)
            local vaults = vim.fn.expand("~") .. "/vaults/"
            if vim.startswith(path, vaults) then
              return false
            end
          end,
        },
        latex = { enable = true },
      })
    end,
  },
  {
    -- browser preview for docs too big to read inline; renders mermaid natively in the browser
    "toppair/peek.nvim",
    build = "deno task --quiet build:fast",
    ft = { "markdown" },
    keys = {
      {
        "<leader>mp",
        function()
          local peek = require("peek")
          if peek.is_open() then
            peek.close()
          else
            peek.open()
          end
        end,
        ft = "markdown",
        desc = "Markdown preview (browser)",
      },
    },
    config = function()
      require("peek").setup({ app = "browser" }) -- open in the default browser, not peek's webview window
    end,
  },
}
