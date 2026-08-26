return {
  "kevinhwang91/nvim-hlslens",
  event = "VeryLazy",
  config = function()
    require("hlslens").setup({
      calm_down = true,
      nearest_only = true,
    })

    -- Integrate hlslens with default search keymaps
    local kopts = { noremap = true, silent = true }

    vim.api.nvim_set_keymap(
      "n",
      "n",
      [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR>zzzv<Cmd>lua require('hlslens').start()<CR>]],
      kopts
    )
    vim.api.nvim_set_keymap(
      "n",
      "N",
      [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR>zzzv<Cmd>lua require('hlslens').start()<CR>]],
      kopts
    )
    vim.api.nvim_set_keymap("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
    vim.api.nvim_set_keymap("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
    vim.api.nvim_set_keymap("n", "g*", [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
    vim.api.nvim_set_keymap("n", "g#", [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

    -- Clear search highlight when done
    vim.api.nvim_set_keymap(
      "n",
      "<Esc>",
      "<Cmd>noh<CR><Esc>",
      { noremap = true, silent = true }
    )
  end,
}
