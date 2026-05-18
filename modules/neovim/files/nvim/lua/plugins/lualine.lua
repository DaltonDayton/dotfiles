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

    -- Compact LSP indicator: gear icon + count of attached clients.
    -- Use :checkhealth lsp (or :lua vim.print(vim.lsp.get_clients()) to see names).
    -- "\239\128\147" is the UTF-8 encoding of U+F013 (fa-cog) in nerd fonts. ⚙
    local lsp_icon = "\239\128\147"
    local function lsp_count()
      local n = #vim.lsp.get_clients({ bufnr = 0 })
      if n == 0 then return "" end
      return lsp_icon .. " " .. n
    end

    lualine.setup({
      options = {
        theme = "auto",
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
          { lsp_count },
          { "encoding" },
          { "fileformat" },
          { "filetype" },
        },
      },
    })
  end,
}
