return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ---@module 'obsidian'
  ---@type obsidian.config
  keys = {
    { "<leader>of", "<cmd>Obsidian quick_switch<cr>", desc = "Find note" },
    { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Search vault" },
    { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note" },
    { "<leader>ot", "<cmd>Obsidian template<cr>", desc = "Insert template" },
    { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
    { "<leader>ol", "<cmd>Obsidian links<cr>", desc = "Links in note" },
    { "<leader>oa", "<cmd>Obsidian tags<cr>", desc = "Tags" },
    { "<leader>or", "<cmd>Obsidian rename<cr>", desc = "Rename note" },
    { "<leader>oc", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Toggle checkbox" },
    { "<leader>ow", "<cmd>Obsidian workspace<cr>", desc = "Switch workspace" },
    { "<leader>op", "<cmd>Obsidian paste_img<cr>", desc = "Paste image" },
    { "<leader>oe", "<cmd>Obsidian extract_note<cr>", mode = "v", desc = "Extract to note" },
    { "<leader>ok", "<cmd>Obsidian link<cr>", mode = "v", desc = "Link selection" },
  },
  opts = {
    legacy_commands = false,
    workspaces = {
      {
        name = "Personal",
        path = "~/vaults/Personal",
      },
      {
        name = "Work",
        path = "~/vaults/Work",
      },
    },
    new_notes_location = "notes_subdir",
    notes_subdir = "1 - Fleeting Notes",
    templates = {
      folder = "5 - Templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
    },
    attachments = {
      folder = "0 - Files",
    },
  },
}
