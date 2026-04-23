return {
  "kristijanhusak/vim-dadbod-ui",
  dependencies = {
    { "tpope/vim-dadbod", lazy = true },
    { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
  },
  cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
  keys = {
    { "<leader>ed", "<cmd>DBUIToggle<CR>", desc = "Database UI Toggle" },
  },
  init = function()
    vim.g.db_ui_use_nerd_fonts = 1
    vim.g.db_ui_auto_execute_table_helpers = 1
    vim.g.db_ui_table_helpers = {
      postgresql = {
        Count = 'select count(*) from "{table}"',
        Explain = 'EXPLAIN ANALYZE SELECT * FROM "{table}"',
      },
      sqlite = {
        Count = 'select count(*) from "{table}"',
        Explain = 'EXPLAIN QUERY PLAN SELECT * FROM "{table}"',
      },
      mysql = {
        Count = "select count(*) from `{table}`",
        Explain = "EXPLAIN SELECT * FROM `{table}`",
      },
      sqlserver = {
        Count = "select count(*) from [{table}]",
        Explain = "SET SHOWPLAN_TEXT ON; GO; SELECT * FROM [{table}]; GO; SET SHOWPLAN_TEXT OFF; GO;",
      },
    }
  end,
}
