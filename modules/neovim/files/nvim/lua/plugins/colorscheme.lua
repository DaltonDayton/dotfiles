return {
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        custom_highlights = function(colors)
          -- https://catppuccin.com/palette/#flavor-mocha
          return {
            -- Pink indent lines
            SnacksIndent = { fg = colors.surface0 },
            SnacksIndentScope = { fg = colors.pink },

            -- Git signs with catppuccin colors
            GitSignsAdd = { fg = colors.green },
            GitSignsChange = { fg = colors.yellow },
            GitSignsDelete = { fg = colors.red },
            GitSignsAddNr = { fg = colors.green },
            GitSignsChangeNr = { fg = colors.yellow },
            GitSignsDeleteNr = { fg = colors.red },

            -- Inactive window highlighting
            NormalFloat = { fg = colors.text, bg = colors.mantle },
            FloatBorder = { fg = colors.mauve },

            -- Visual selection (using lighter surface colors for blend effect)
            Visual = { bg = colors.surface2 },
            VisualNOS = { bg = colors.surface1 },

            -- Cursorline (using lighter surface color)
            CursorLine = { bg = colors.surface0 },
            CursorLineNr = { fg = colors.pink },

            -- Completion menu
            Pmenu = { fg = colors.text, bg = colors.surface0 },
            PmenuSel = { fg = colors.base, bg = colors.blue },
            PmenuSbar = { bg = colors.surface1 },
            PmenuThumb = { bg = colors.surface2 },

            -- Which-key
            WhichKey = { fg = colors.blue },
            WhichKeyGroup = { fg = colors.pink },
            WhichKeySeparator = { fg = colors.surface0 },
            WhichKeyDesc = { fg = colors.text },
            WhichKeyFloat = { bg = colors.mantle },

            -- Todo comments
            Todo = { fg = colors.yellow, style = { "bold", "italic" } },
            TodoBgTODO = { fg = colors.blue, bg = colors.surface0, style = { "bold" } },
            TodoBgFIX = { fg = colors.red, bg = colors.surface0, style = { "bold" } },
            TodoBgFIXME = { fg = colors.maroon, bg = colors.surface0, style = { "bold" } },
            TodoBgHACK = { fg = colors.peach, bg = colors.surface0, style = { "bold" } },
            TodoBgWARN = { fg = colors.yellow, bg = colors.surface0, style = { "bold" } },
            TodoBgNOTE = { fg = colors.green, bg = colors.surface0, style = { "bold" } },
            TodoBgPERF = { fg = colors.mauve, bg = colors.surface0, style = { "bold" } },
            TodoBgTEST = { fg = colors.teal, bg = colors.surface0, style = { "bold" } },
            TodoFgTODO = { fg = colors.blue },
            TodoFgFIX = { fg = colors.red },
            TodoFgFIXME = { fg = colors.maroon },
            TodoFgHACK = { fg = colors.peach },
            TodoFgWARN = { fg = colors.yellow },
            TodoFgNOTE = { fg = colors.green },
            TodoFgPERF = { fg = colors.mauve },
            TodoFgTEST = { fg = colors.teal },
          }
        end,
      })
      vim.cmd("colorscheme catppuccin")
    end,
    opts = {
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        markdown = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        -- navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        semantic_tokens = true,
        snacks = true,
        telescope = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
  },
}
