return {
  "ThePrimeagen/99",
  dependencies = {
    { "saghen/blink.compat", version = "2.*" }, -- 99's blink completion source is an nvim-cmp-compat shim
  },
  keys = {
    { "<leader>av", function() require("99").visual() end, mode = "v", desc = "Edit selection (99)" },
    { "<leader>as", function() require("99").search() end, desc = "Search project (99)" },
    { "<leader>ao", function() require("99").open() end, desc = "Open last result (99)" },
    { "<leader>ax", function() require("99").stop_all_requests() end, desc = "Stop requests (99)" },
    { "<leader>al", function() require("99").view_logs() end, desc = "View logs (99)" },
    -- telescope-free model picker (99's built-in select_model needs telescope; we use snacks' vim.ui.select)
    {
      "<leader>am",
      function()
        local _99 = require("99")
        -- 99's hardcoded Claude model list is stale; prepend newer ids it omits.
        local extra = { "claude-opus-4-8", "claude-opus-4-8[1m]" }
        _99.get_provider().fetch_models(function(models)
          local list, seen = {}, {}
          for _, m in ipairs(vim.list_extend(vim.deepcopy(extra), models)) do
            if not seen[m] then
              seen[m] = true
              list[#list + 1] = m
            end
          end
          vim.ui.select(list, { prompt = "99 model (current: " .. _99.get_model() .. ")" }, function(m)
            if m then
              _99.set_model(m)
              vim.notify("99 model: " .. m)
            end
          end)
        end)
      end,
      desc = "Select model (99)",
    },
  },
  config = function()
    local _99 = require("99")
    _99.setup({
      provider = _99.Providers.ClaudeCodeProvider, -- reuse the claude CLI (Max sub); default is OpenCodeProvider
      completion = { source = "blink" }, -- @files / #rules completion via blink.cmp
      md_files = { "CLAUDE.md", "AGENT.md" }, -- auto-attach these up the dir tree as context
    })
  end,
}
