return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        svelte = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        graphql = { "prettier" },
        liquid = { "prettier" },
        lua = { "stylua" },
        python = { "isort", "black" },
        ruby = { "rubocop" },
        eruby = { "erb_format" },
        go = { "goimports", "gofumpt" },
      },
      format_on_save = function(bufnr)
        -- Disable with a global or buffer-local variable
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
        local path = vim.fn.expand("%:p")
        if vim.startswith(path, vim.fn.expand("~") .. "/vaults/") then return end
        return {
          lsp_fallback = true,
          async = false,
          timeout_ms = 1000,
        }
      end,
    })

    vim.keymap.set(
      { "n", "v" },
      "<leader>cf",
      function()
        conform.format({
          lsp_fallback = true,
          async = false,
          timeout_ms = 1000,
        })
      end,
      { desc = "Format file or range" }
    )
    vim.keymap.set("n", "<leader>ct", function() vim.cmd("FormatToggle") end, { desc = "Toggle format on save" })
  end,
}
