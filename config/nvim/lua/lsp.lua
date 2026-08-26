-- ============================================================================
-- Global LSP Configuration
-- ============================================================================
-- This file handles LSP settings that apply to ALL servers:
-- - Keymaps (via LspAttach autocmd)
-- - Diagnostic configuration (icons, signs, float behavior)
-- - Handlers (hover, signature help)
-- - UI customization (borders, etc.)
--
-- This runs during init.lua, before plugins load.
--
-- DO NOT put server-specific configs here. Those go in:
-- - lua/plugins/lsp/mason.lua (auto-install & auto-config with defaults)
-- - lua/plugins/lsp/lsp.lua (manually enable servers not auto-configured)
-- - after/lsp/{server_name}.lua (custom per-server config)
-- ============================================================================

local keymap = vim.keymap -- for conciseness
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    -- Note: gd, gD, grr, gri, grt, gO are defined in lua/plugins/snacks.lua using Snacks picker
    local opts = { buffer = ev.buf, silent = true }

    -- gra (code action) and grn (rename) provided by Neovim 0.11+ defaults

    opts.desc = "Signature help"
    keymap.set("n", "<leader>cs", vim.lsp.buf.signature_help, opts)

    -- Note: <leader>sd and <leader>sD for diagnostics are in lua/plugins/snacks.lua
    opts.desc = "Show line diagnostics"
    keymap.set("n", "<leader>cd", vim.diagnostic.open_float, opts) -- show diagnostics for line

    -- [d / ]d (diagnostic jump) and K (hover) provided by Neovim 0.11+ defaults

    opts.desc = "Restart LSP"
    keymap.set("n", "<leader>cS", function()
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = ev.buf })) do
        local name, cfg = client.name, client.config
        client:stop()
        vim.defer_fn(function() vim.lsp.start(cfg) end, 100)
        vim.notify("Restarted LSP: " .. name)
      end
    end, opts)
  end,
})

-- vim.lsp.inlay_hint.enable(true)

local severity = vim.diagnostic.severity

vim.diagnostic.config({
  signs = {
    text = {
      [severity.ERROR] = " ",
      [severity.WARN] = " ",
      [severity.HINT] = "󰠠 ",
      [severity.INFO] = " ",
    },
  },
  float = { border = "rounded" },
  virtual_lines = { current_line = true },
})
