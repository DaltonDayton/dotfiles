return {
  "kevinhwang91/nvim-hlslens",
  event = "VeryLazy",
  config = function()
    require("hlslens").setup({
      calm_down = true,
      nearest_only = true,
    })

    -- Integrate hlslens with default search keymaps
    local function search(key, desc, center)
      vim.keymap.set("n", key, function()
        vim.cmd(("normal! %d%s"):format(vim.v.count1, key))
        if center then vim.cmd("normal! zzzv") end
        require("hlslens").start()
      end, { silent = true, desc = desc })
    end
    search("n", "Next match (centered, lens)", true)
    search("N", "Previous match (centered, lens)", true)
    search("*", "Search word under cursor forward")
    search("#", "Search word under cursor backward")
    search("g*", "Search word under cursor forward (partial)")
    search("g#", "Search word under cursor backward (partial)")

    -- Clear search highlight, and multicursors (0.13+; a no-op namespace before
    -- that). Built-in <C-l> would do both but vim-tmux-navigator owns <C-l>.
    vim.keymap.set("n", "<Esc>", function()
      vim.cmd.nohlsearch()
      vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("nvim.multicursor"), 0, -1)
    end, { silent = true, desc = "Clear search highlight and multicursors" })
  end,
}
