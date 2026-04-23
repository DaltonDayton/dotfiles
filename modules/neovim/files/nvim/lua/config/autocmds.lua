-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Set conceallevel=2 for .md files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt.conceallevel = 2
  end,
  desc = "Set conceallevel to 2 for markdown files",
})

-- Autocommand to enable relative line numbers in netrw
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.opt_local.relativenumber = true -- Enable relative line numbers
    vim.opt_local.number = true -- Enable absolute line numbers
  end,
})

-- Command to disable formatting
vim.api.nvim_create_user_command("FormatDisable", function(args)
  if args.bang then
    vim.b.disable_autoformat = true
  else
    vim.g.disable_autoformat = true
  end
end, {
  desc = "Disable autoformat-on-save",
  bang = true,
})

-- Command to enable formatting
vim.api.nvim_create_user_command("FormatEnable", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, {
  desc = "Re-enable autoformat-on-save",
})

-- Command to toggle formatting
vim.api.nvim_create_user_command("FormatToggle", function()
  if vim.g.disable_autoformat or vim.b.disable_autoformat then
    -- If formatting is currently disabled, enable it
    vim.cmd("FormatEnable")
    print("Autoformatting is now enabled.")
  else
    -- If formatting is currently enabled, disable it
    vim.cmd("FormatDisable")
    print("Autoformatting is now disabled.")
  end
end, {
  desc = "Toggle autoformat-on-save using existing enable/disable commands",
})
-- Auto-close some filetypes with 'q'
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "help", "man", "lspinfo", "checkhealth" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
  desc = "Close certain filetypes with q",
})

-- Restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 1 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
  desc = "Restore cursor position when reopening files",
})
