return {
  "olimorris/codecompanion.nvim",
  version = "^19.0.0", -- pin major; v20+ may change config keys (docs recommend pinning)
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
  keys = {
    { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Chat toggle" },
    { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "Actions palette" },
    { "<leader>ad", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Add selection to chat" },
    { "<leader>an", "<cmd>CodeCompanionChat<cr>", desc = "New chat" },
    -- Prompt library (all chat-strategy, work over ACP)
    { "<leader>ape", function() require("codecompanion").prompt("explain") end, mode = "v", desc = "Explain code" },
    { "<leader>apf", function() require("codecompanion").prompt("fix") end, mode = "v", desc = "Fix code" },
    { "<leader>apt", function() require("codecompanion").prompt("tests") end, mode = "v", desc = "Unit tests" },
    { "<leader>apl", function() require("codecompanion").prompt("lsp") end, mode = "v", desc = "Explain LSP diagnostics" },
    { "<leader>apc", function() require("codecompanion").prompt("commit") end, desc = "Commit message" },
  },
  opts = {
    -- Drive chat through Claude Code via ACP, so it reuses the Max sub (no API key).
    -- Auth: $CLAUDE_CODE_OAUTH_TOKEN (generate once with `claude setup-token`).
    -- Inline/cmd strategies need an HTTP adapter (API key), so we only use chat here; 99 covers inline edits.
    interactions = {
      chat = { adapter = "claude_code" },
    },
  },
}
