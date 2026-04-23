return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 500
  end,
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  },
  config = function()
    require("which-key").setup()

    -- Document key groups only - individual keybinds have their own desc where defind
    require("which-key").add({
      -- LSP Navigation
      { "g", group = "[G]oto" },

      -- Leader groups
      { "<leader>a", group = "[A]ugment (AI)" },
      { "<leader>a_", hidden = true },
      { "<leader>b", group = "[B]uffer" },
      { "<leader>b_", hidden = true },
      { "<leader>c", group = "[C]ode/LSP" },
      { "<leader>c_", hidden = true },
      { "<leader>d", group = "[D]ebug" },
      { "<leader>d_", hidden = true },
      { "<leader>e", group = "[E]xplorer" },
      { "<leader>e_", hidden = true },
      { "<leader>f", group = "[F]ind" },
      { "<leader>f_", hidden = true },
      { "<leader>g", group = "[G]it" },
      { "<leader>g_", hidden = true },
      { "<leader>gh", group = "Git [H]unk" },
      { "<leader>gh_", hidden = true },
      { "<leader>ght", group = "[T]oggle (Git)" },
      { "<leader>ght_", hidden = true },
      { "<leader>m", group = "[M]arks (Harpoon)" },
      { "<leader>m_", hidden = true },
      { "<leader>o", group = "[O]bsidian" },
      { "<leader>o_", hidden = true },
      { "<leader>n", group = "[N]eotest" },
      { "<leader>n_", hidden = true },
      { "<leader>np", group = "[P]laywright" },
      { "<leader>np_", hidden = true },
      { "<leader>q", group = "[Q]uickfix" },
      { "<leader>q_", hidden = true },
      { "<leader>s", group = "[S]earch" },
      { "<leader>s_", hidden = true },
      { "<leader>t", group = "[T]abs" },
      { "<leader>t_", hidden = true },
      { "<leader>u", group = "[U]I Toggles" },
      { "<leader>u_", hidden = true },
      { "<leader>v", group = "[V]isual Selection" },
      { "<leader>v_", hidden = true },
      { "<leader>w", group = "[W]indow" },
      { "<leader>w_", hidden = true },
    })
  end,
}
