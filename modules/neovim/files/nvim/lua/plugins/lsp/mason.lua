-- ============================================================================
-- Mason: LSP/Formatter/Linter Installation & Auto-configuration
-- ============================================================================
-- This file handles:
-- 1. Installing LSP servers via Mason
-- 2. Auto-configuring installed servers with their DEFAULT configs
-- 3. Installing formatters and linters
--
-- mason-lspconfig automatically calls lspconfig.{server}.setup() for all
-- servers listed in ensure_installed, using their default configurations.
--
-- If a server needs CUSTOM configuration, you have two options:
-- 1. Use lua/lsp.lua for manual vim.lsp.config() setup (runs during init)
-- 2. Use after/plugin/lsp/{server_name}.lua for overrides (runs after plugins load)
-- ============================================================================

return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "lua_ls",
        "ts_ls",
        "html",
        "cssls",
        "emmet_language_server",
        "pyright",
        "eslint",
        "csharp_ls",
        "ruby_lsp",
        "gopls",
      },
    },
    dependencies = {
      {
        "mason-org/mason.nvim",
        opts = {
          {
            "mason-org/mason-lspconfig.nvim",
            opts = {},
            dependencies = {
              { "mason-org/mason.nvim", opts = {} },
              "neovim/nvim-lspconfig",
            },
          },
        },
      },
      "neovim/nvim-lspconfig",
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        "prettier", -- prettier formatter
        "stylua", -- lua formatter
        "isort", -- python formatter
        "black", -- python formatter
        "pylint", -- python linter
        "rubocop", -- ruby formatter/linter
        "goimports", -- go formatter (handles imports)
        "gofumpt", -- stricter gofmt
        "golangci-lint", -- go linter aggregator
      },
    },
    dependencies = {
      "williamboman/mason.nvim",
    },
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed = {
          "python",
          "coreclr",
          "js", -- Modern Node.js debugger for JavaScript/TypeScript (includes Playwright)
          "delve", -- go debugger
        },
        handlers = {
          function(config)
            -- all sources with no handler get passed here
            -- Keep original functionality
            require("mason-nvim-dap").default_setup(config)
          end,
          -- Note: js-debug-adapter is manually configured in dap.lua
          -- mason-nvim-dap doesn't auto-setup it properly
        },
      })
    end,
    dependencies = {
      "williamboman/mason.nvim",
    },
  },
}
