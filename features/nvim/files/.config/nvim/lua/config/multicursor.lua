-- Leader aliases for the builtin multicursor (0.13+). The builtin keys (Q, zq,
-- q=, gQ, ]C) still work; these are mnemonic aliases. Each maps straight to
-- the builtin so the cascade replays them like any other normal command.
if vim.fn.has("nvim-0.13") == 0 then return end

local map = vim.keymap.set
local function clear()
  vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("nvim.multicursor"), 0, -1)
end

map("n", "<leader>ka", "Q", { desc = "Toggle cursor here" })
map("x", "<leader>kl", "Q", { desc = "Cursor on each selected line" })
map({ "n", "x" }, "<leader>ks", "zqgn", { desc = "Cursor at every search match" })
map({ "n", "x" }, "<leader>kw", "zqw", { desc = "Cursor on every word" })
map("n", "<leader>kf", "q=", { desc = "Toggle follow mode" })
map("n", "<leader>kr", "gQ", { desc = "Restore previous cursors" })
map("n", "<leader>kn", "]C", { desc = "Next cursor" })
map("n", "<leader>kp", "[C", { desc = "Previous cursor" })
map("n", "<leader>kc", clear, { desc = "Clear cursors" })
