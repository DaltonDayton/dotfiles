return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  dependencies = { "windwp/nvim-ts-autotag" },
  config = function()
    local parsers = {
      "bash",
      "c",
      "cpp",
      "c_sharp",
      "css",
      "diff",
      "dockerfile",
      "embedded_template",
      "gitignore",
      "go",
      "gomod",
      "gosum",
      "html",
      "javascript",
      "json",
      "latex",
      "lua",
      "markdown",
      "markdown_inline",
      "python",
      "query",
      "regex",
      "ruby",
      "sql",
      "tsx",
      "typescript",
      "vim",
      "vimdoc",
      "yaml",
    }

    require("nvim-treesitter").install(parsers)

    local filetypes = {
      "bash",
      "c",
      "cpp",
      "cs",
      "css",
      "diff",
      "dockerfile",
      "eruby",
      "gitignore",
      "go",
      "gomod",
      "gosum",
      "help",
      "html",
      "javascript",
      "javascriptreact",
      "json",
      "lua",
      "markdown",
      "python",
      "query",
      "ruby",
      "sh",
      "sql",
      "typescript",
      "typescriptreact",
      "vim",
      "yaml",
    }

    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldmethod = "expr"
        -- Only where nvim-treesitter ships an indent query; otherwise the
        -- expression returns -1 for every line and new lines start at column
        -- 0 (c_sharp has none, so cs keeps Vim's own indent/cs.vim).
        local lang = vim.treesitter.language.get_lang(args.match)
        if lang and vim.treesitter.query.get(lang, "indents") then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })

    require("nvim-ts-autotag").setup()
  end,
}
