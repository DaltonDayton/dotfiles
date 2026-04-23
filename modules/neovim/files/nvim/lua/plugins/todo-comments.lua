return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
  },
  -- Keywords
  -- TODO: asdf
  -- FIXME: asdf
  -- HACK: asdf
  -- WARN: asdf
  -- NOTE: asdf
  -- PERF: asdf
  -- TEST: asdf
  keys = {
    { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo" },
    {
      "<leader>sT",
      function() Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } }) end,
      desc = "Todo/Fix/Fixme",
    },
  },
}
