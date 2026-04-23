return {
  "saghen/blink.cmp",
  -- optional: provides snippets for the snippet source
  dependencies = {
    "rafamadriz/friendly-snippets",
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      build = "make install_jsregexp",
      config = function()
        local ls = require("luasnip")
        local types = require("luasnip.util.types")

        -- Load friendly-snippets
        require("luasnip.loaders.from_vscode").lazy_load()

        -- Load custom snippets from ~/.config/nvim/snippets/ (VS Code style JSON)
        require("luasnip.loaders.from_vscode").lazy_load({
          paths = { vim.fn.stdpath("config") .. "/snippets" },
        })

        -- Load custom Lua snippets from ~/.config/nvim/lua/snippets/
        require("luasnip.loaders.from_lua").lazy_load({
          paths = { vim.fn.stdpath("config") .. "/lua/snippets" },
        })

        -- LuaSnip configuration
        ls.config.set_config({
          -- Remember last snippet for jumping back
          history = true,
          -- Update dynamic snippets as you type
          updateevents = "TextChanged,TextChangedI",
          -- Enable autotrigger snippets
          enable_autosnippets = true,
          -- Show virtual text for snippet nodes
          ext_opts = {
            [types.choiceNode] = {
              active = {
                virt_text = { { "●", "DiagnosticWarn" } },
              },
            },
          },
        })

        -- Keymaps for snippet navigation
        -- <C-l>: Expand or jump to next node
        vim.keymap.set({ "i", "s" }, "<C-l>", function()
          if ls.expand_or_jumpable() then ls.expand_or_jump() end
        end, { silent = true, desc = "Expand or jump to next snippet node" })

        -- <C-h>: Jump to previous node
        vim.keymap.set({ "i", "s" }, "<C-h>", function()
          if ls.jumpable(-1) then ls.jump(-1) end
        end, { silent = true, desc = "Jump to previous snippet node" })

        -- <C-j>: Cycle through choices
        vim.keymap.set({ "i", "s" }, "<C-j>", function()
          if ls.choice_active() then ls.change_choice(1) end
        end, { silent = true, desc = "Cycle through snippet choices" })
      end,
    },
  },

  -- use a release tag to download pre-built binaries
  version = "1.*",
  -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
  -- build = 'cargo build --release',
  -- If you use nix, you can build from source using latest nightly rust with:
  -- build = 'nix run .#build-plugin',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
    -- 'super-tab' for mappings similar to vscode (tab to accept)
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- All presets have the following mappings:
    -- C-space: Open menu or open docs if already open
    -- C-n/C-p or Up/Down: Select next/previous item
    -- C-e: Hide menu
    -- C-k: Toggle signature help (if signature.enabled = true)
    --
    -- See :h blink-cmp-config-keymap for defining your own keymap
    keymap = { preset = "enter" },

    signature = {
      enabled = true,
      window = { border = "rounded" },
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = "mono",
    },

    -- Automatically show documentation popup when highlighting completion items
    completion = {
      menu = {
        border = "rounded",
        winblend = 0, -- Transparency: 0 = opaque, 100 = fully transparent
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 0,
        window = {
          border = "rounded",
          winblend = 0,
        },
      },
    },

    -- Default list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      per_filetype = {
        sql = { "dadbod", "snippets", "buffer" },
        mysql = { "dadbod", "snippets", "buffer" },
        plsql = { "dadbod", "snippets", "buffer" },
      },
      providers = {
        dadbod = {
          name = "Dadbod",
          module = "vim_dadbod_completion.blink",
        },
      },
    },

    -- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
    -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
    -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
    --
    -- See the fuzzy documentation for more information
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
