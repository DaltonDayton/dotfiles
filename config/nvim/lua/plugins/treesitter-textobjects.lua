return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("nvim-treesitter-textobjects").setup({
      select = {
        lookahead = true,
        selection_modes = {
          ["@parameter.outer"] = "v",
          ["@function.outer"] = "V",
        },
        include_surrounding_whitespace = false,
      },
      move = {
        set_jumps = true,
      },
    })

    local select = require("nvim-treesitter-textobjects.select")
    local move = require("nvim-treesitter-textobjects.move")

    local function map_select(lhs, capture, desc)
      vim.keymap.set({ "x", "o" }, lhs, function() select.select_textobject(capture, "textobjects") end, { desc = desc })
    end

    map_select("af", "@function.outer", "Around function")
    map_select("if", "@function.inner", "Inside function")
    map_select("ac", "@class.outer", "Around class")
    map_select("ic", "@class.inner", "Inside class")
    map_select("aa", "@parameter.outer", "Around parameter")
    map_select("ia", "@parameter.inner", "Inside parameter")

    local function map_move(lhs, fn, capture, desc)
      vim.keymap.set({ "n", "x", "o" }, lhs, function() move[fn](capture, "textobjects") end, { desc = desc })
    end

    map_move("]f", "goto_next_start", "@function.outer", "Next function start")
    map_move("[f", "goto_previous_start", "@function.outer", "Prev function start")
    map_move("]c", "goto_next_start", "@class.outer", "Next class start")
    map_move("[c", "goto_previous_start", "@class.outer", "Prev class start")
  end,
}
