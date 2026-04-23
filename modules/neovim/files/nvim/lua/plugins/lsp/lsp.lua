-- ============================================================================
-- Per-Server LSP Configurations
-- ============================================================================
-- This file is for MANUALLY enabling specific LSP servers that aren't
-- auto-enabled by mason-lspconfig.
--
-- mason-lspconfig automatically enables servers in its ensure_installed list
-- with default configs, but some servers (like djlsp) need manual enabling.
--
-- Use vim.lsp.enable("{server_name}") here for servers that need to be
-- manually started.
--
-- For servers needing CUSTOM configuration (root_markers, settings, etc.),
-- use after/plugin/lsp/{server_name}.lua instead, where you can define
-- vim.lsp.config() and vim.lsp.enable() together.
-- ============================================================================

return {
  vim.lsp.enable("djlsp"),
}
