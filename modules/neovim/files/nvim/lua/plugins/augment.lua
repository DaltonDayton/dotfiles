return {
  "augmentcode/augment.vim",
  event = "InsertEnter",
  -- These globals are read at plugin-load time (plugin/augment.vim runs
  -- SetupKeybinds and reads workspace folders before config() executes), so
  -- they must be set in init, not config. Setting them in config silently
  -- has no effect.
  init = function()
    local root_dir = vim.lsp.buf.list_workspace_folders()[1] or vim.fn.getcwd()
    vim.g.augment_workspace_folders = { root_dir }
    vim.g.augment_disable_tab_mapping = true
  end,
  config = function()
    vim.keymap.set("i", "<C-y>", "<cmd>call augment#Accept()<CR>", { silent = true, desc = "Augment - Accept suggestion" })
  end,
  keys = {
    {
      "<leader>am",
      "<cmd>Augment chat<cr>",
      mode = { "n", "v" },
      desc = "Augment - Send chat message",
    },
    { "<leader>an", "<cmd>Augment chat-new<cr>", mode = { "n" }, desc = "Augment - New chat" },
    {
      "<leader>at",
      "<cmd>Augment chat-toggle<cr>",
      mode = { "n" },
      desc = "Augment - Toggle chat",
    },
    {
      "<leader>as",
      "<cmd>Augment status<cr>",
      mode = { "n" },
      desc = "Augment - View status",
    },
    { "<leader>al", "<cmd>Augment log<cr>", mode = { "n" }, desc = "Augment - View log" },
    { "<leader>ai", "<cmd>Augment signin<cr>", mode = { "n" }, desc = "Augment - Sign in" },
    { "<leader>ao", "<cmd>Augment signout<cr>", mode = { "n" }, desc = "Augment - Sign out" },
  },
}
