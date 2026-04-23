return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-mini/mini.icons" },
  config = function()
    local ok, lualine = pcall(require, "lualine")
    if not ok then
      vim.notify("lualine failed to load", vim.log.levels.WARN)
      return
    end

    local lazy_status = require("lazy.status")

    -- Function to display recording macro message
    local function macro_recording()
      local recording_reg = vim.fn.reg_recording()
      if recording_reg ~= "" then
        return "Recording @" .. recording_reg
      else
        return ""
      end
    end

    -- Function to display active LSP client(s)
    local function lsp_clients()
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      if #clients == 0 then return "" end
      local names = {}
      for _, client in ipairs(clients) do
        table.insert(names, client.name)
      end
      return table.concat(names, ", ")
    end

    lualine.setup({
      options = {
        theme = "catppuccin-mocha",
      },
      sections = {
        lualine_b = {
          { "branch" },
          { "diagnostics" },
        },
        lualine_c = {
          { macro_recording },
          {
            "filename",
            path = 1,
            file_status = true,
            newfile_status = true,
            symbols = {
              modified = "[+]",
              readonly = "[-]",
              unnamed = "[No Name]",
              newfile = "[New]",
            },
          },
        },
        lualine_x = {
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
          },
          { lsp_clients },
          { "encoding" },
          { "fileformat" },
          { "filetype" },
        },
      },
    })
  end,
}
