return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  event = { "BufReadPre", "BufNewFile" },
  build = ":TSUpdate",
  dependencies = {
    "windwp/nvim-ts-autotag",
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    -- import nvim-treesitter plugin
    local treesitter = require("nvim-treesitter.configs")

    -- Compat shim for Neovim 0.12+: nvim-treesitter master (archived) passes
    -- `match[id]` to directive/predicate handlers as a single TSNode, but
    -- Neovim 0.12 now passes TSNode[] arrays. Wrap registration during setup
    -- so nvim-treesitter's handlers receive single nodes, then restore.
    local ts_query = vim.treesitter.query
    local orig_add_directive = ts_query.add_directive
    local orig_add_predicate = ts_query.add_predicate
    local function normalize_match(match)
      local out = {}
      for k, v in pairs(match) do
        out[k] = type(v) == "table" and v[#v] or v
      end
      return out
    end
    local function wrap(fn)
      return function(name, handler, opts)
        return fn(name, function(match, ...)
          return handler(normalize_match(match), ...)
        end, opts)
      end
    end
    ts_query.add_directive = wrap(orig_add_directive)
    ts_query.add_predicate = wrap(orig_add_predicate)

    -- query_predicates may have loaded before this point; re-require to
    -- re-register its handlers through our wrappers (opts = { force = true }).
    package.loaded["nvim-treesitter.query_predicates"] = nil
    require("nvim-treesitter.query_predicates")

    -- configure treesitter
    treesitter.setup({
      highlight = {
        enable = true,
      },
      -- enable indentation
      indent = { enable = true },
      -- enable autotagging (w/ nvim-ts-autotag plugin)
      autotag = {
        enable = true,
      },
      auto_install = false,
      -- ensure these language parsers are installed
      ensure_installed = {
        "json",
        "javascript",
        "typescript",
        "tsx",
        "yaml",
        "html",
        "css",
        "markdown",
        "markdown_inline",
        "bash",
        "lua",
        "vim",
        "dockerfile",
        "gitignore",
        "query",
        "vimdoc",
        "c",
        "sql",
        "diff",
        "c_sharp",
        "python",
        "regex",
        "ruby",
        "embedded_template",
        "go",
        "gomod",
        "gosum",
      },
      -- TODO: Ask AI what this is useful for
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<leader>vi",
          node_incremental = "<leader>vn",
          scope_incremental = false,
          node_decremental = "<leader>vb",
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            ["]f"] = "@function.outer",
            ["]c"] = "@class.outer",
          },
          goto_previous_start = {
            ["[f"] = "@function.outer",
            ["[c"] = "@class.outer",
          },
        },
      },
    })

    ts_query.add_directive = orig_add_directive
    ts_query.add_predicate = orig_add_predicate
  end,
}
