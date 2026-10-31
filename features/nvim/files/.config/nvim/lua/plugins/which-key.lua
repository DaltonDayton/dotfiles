return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 500
  end,
  opts = {
    preset = "modern",
  },
  config = function(_, opts)
    require("which-key").setup(opts)

    -- Group titles live in lua/cheatsheet/groups.lua, shared with <leader>?.
    local spec = {}
    for _, g in ipairs(require("cheatsheet.groups")) do
      if g.prefix ~= "" and g.prefix ~= "<leader>" and g.prefix ~= "<" and g.prefix ~= "<F" then
        table.insert(spec, { g.prefix, group = g.title })
        table.insert(spec, { g.prefix .. "_", hidden = true })
      end
    end
    require("which-key").add(spec)
  end,
}
