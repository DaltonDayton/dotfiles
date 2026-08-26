return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    -- Configure pylint to use .venv python if available
    local function get_python_path()
      local venv_python = vim.fn.getcwd() .. "/.venv/bin/python"
      if vim.fn.executable(venv_python) == 1 then return venv_python end
      return "python" -- fallback to system python
    end

    -- Override pylint command to use correct python
    lint.linters.pylint.cmd = get_python_path()
    lint.linters.pylint.args = {
      "-m",
      "pylint",
      "--output-format",
      "text",
      "--msg-template",
      "{path}:{line}:{column}:{C}: [{symbol}] {msg}",
      "--reports",
      "no",
    }

    lint.linters_by_ft = {
      python = { "pylint" },
      go = { "golangcilint" },
    }

    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = lint_augroup,
      callback = function() lint.try_lint() end,
    })

    vim.keymap.set("n", "<leader>cl", function() lint.try_lint() end, { desc = "Lint file" })
  end,
}
