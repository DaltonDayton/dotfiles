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
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })

    require("nvim-ts-autotag").setup()
  end,
}
