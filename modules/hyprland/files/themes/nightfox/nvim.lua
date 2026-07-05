return {
  plugin = {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("nightfox").setup({
        options = {
          transparent = true,
          styles = { comments = "italic" },
        },
      })
    end,
  },
  scheme = "nightfox",
  post = function()
    local function clear_bg(group)
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, group, hl)
    end
    for _, g in ipairs({ "NormalFloat", "FloatBorder", "FloatTitle" }) do clear_bg(g) end
    -- default WinSeparator is darker than bg: invisible splits
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#39506d" })
  end,
}
