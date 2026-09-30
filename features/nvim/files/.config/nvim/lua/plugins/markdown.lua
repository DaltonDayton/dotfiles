return {
  {
    -- terminal image backend (kitty graphics protocol); diagram.nvim draws through this
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      processor = "magick_cli", -- use system ImageMagick CLI, avoids the luarocks/hererocks build
      -- clear images when leaving the active tmux window (fixes images stuck on screen
      -- after switching tmux windows); needs `set -g visual-activity off` in tmux.conf
      tmux_show_only_in_active_window = true,
    },
  },
  {
    -- renders ```mermaid (and plantuml/d2) code blocks into inline images via image.nvim + mmdc
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "markdown" },
    config = function()
      require("diagram").setup({
        integrations = { require("diagram.integrations.markdown") },
        renderer_options = {
          mermaid = { theme = "dark", background = "transparent" },
        },
      })
    end,
  },
  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown", "codecompanion" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    config = function()
      -- CodeCompanion chat buffers are markdown content under a non-markdown filetype.
      -- markview calls vim.treesitter.start(), which errors if the filetype has no parser,
      -- so point codecompanion at the markdown parser.
      vim.treesitter.language.register("markdown", "codecompanion")

      require("markview").setup({
        preview = {
          filetypes = { "markdown", "codecompanion" }, -- also render the CodeCompanion chat buffer
          condition = function(buf)
            -- return false skips a buffer, nil falls through to the filetypes allowlist.
            -- Only force-skip inside the vaults dir; let everything else use normal gating
            -- (returning true here would force-attach to NvimTree/pickers and crash treesitter).
            local path = vim.api.nvim_buf_get_name(buf)
            local vaults = vim.fn.expand("~") .. "/vaults/"
            if vim.startswith(path, vaults) then
              return false
            end
          end,
        },
        latex = { enable = true },
      })
    end,
  },
  {
    -- browser preview for docs too big to read inline; renders mermaid natively in the browser
    "toppair/peek.nvim",
    build = "deno task --quiet build:fast",
    ft = { "markdown" },
    keys = {
      {
        "<leader>mp",
        function()
          local peek = require("peek")
          if peek.is_open() then
            peek.close()
          else
            peek.open()
          end
        end,
        ft = "markdown",
        desc = "Markdown preview (browser)",
      },
    },
    config = function()
      require("peek").setup({ app = "browser" }) -- open in the default browser, not peek's webview window
    end,
  },
}
