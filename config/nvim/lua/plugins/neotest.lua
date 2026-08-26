return {
  "nvim-neotest/neotest",
  dependencies = {
    -- Core
    -- "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    -- Adapters
    "nvim-neotest/neotest-python",
    "nvim-neotest/neotest-plenary",
    "nvim-neotest/neotest-vim-test",
    "nsidorenco/neotest-vstest",
    "thenbe/neotest-playwright",
    "marilari88/neotest-vitest",
  },
  config = function()
    local neotest = require("neotest")
    neotest.setup({
      output = {
        open_on_run = true,
      },
      floating = {
        border = "rounded",
        max_height = 0.8,
        max_width = 0.8,
      },
      adapters = {
        -- Python
        require("neotest-python")({
          dap = { justMyCode = false },
          -- !!EXPERIMENTAL!! Enable shelling out to `pytest` to discover test
          -- instances for files containing a parametrize mark (default: false)
          pytest_discover_instances = true,
        }),

        -- C# / dotnet
        require("neotest-vstest")({
          -- Path to dotnet sdk path.
          -- Used in cases where the sdk path cannot be auto discovered.
          -- sdk_path = "/usr/local/dotnet/sdk/9.0.101/",
          -- table is passed directly to DAP when debugging tests.
          dap_settings = {
            type = "coreclr",
          },
          -- If multiple solutions exists the adapter will ask you to choose one.
          -- If you have a different heuristic for choosing a solution you can provide a function here.
          solution_selector = function(solutions)
            return nil -- return the solution you want to use or nil to let the adapter choose.
          end,
          build_opts = {
            -- Arguments that will be added to all `dotnet build` and `dotnet msbuild` commands
            additional_args = {},
          },
        }),

        -- Vitest (JavaScript / TypeScript)
        require("neotest-vitest")({
          -- Walk up the directory tree to find the nearest vite.config.js or vitest.config.js
          cwd = function(file)
            if not file then return vim.uv.cwd() end
            local dir = vim.fn.fnamemodify(file, ":h")
            local vite_config = vim.fn.findfile("vite.config.js", dir .. ";")
            if vite_config ~= "" then return vim.fn.fnamemodify(vite_config, ":p:h") end
            local vitest_config = vim.fn.findfile("vitest.config.js", dir .. ";")
            if vitest_config ~= "" then return vim.fn.fnamemodify(vitest_config, ":p:h") end
            return vim.uv.cwd()
          end,
          vitestConfigFile = function(file)
            if not file then return nil end
            local dir = vim.fn.fnamemodify(file, ":h")
            local vite_config = vim.fn.findfile("vite.config.js", dir .. ";")
            if vite_config ~= "" then return vim.fn.fnamemodify(vite_config, ":p") end
            local vitest_config = vim.fn.findfile("vitest.config.js", dir .. ";")
            if vitest_config ~= "" then return vim.fn.fnamemodify(vitest_config, ":p") end
            return nil
          end,
          filter_dir = function(name) return name ~= "e2e" and name ~= "node_modules" end,
        }),

        -- Playwright
        require("neotest-playwright").adapter({
          options = {
            persist_project_selection = true,
            enable_dynamic_test_discovery = true,
            preset = "none", -- "none" | "headed" | "debug"
            get_cwd = function() return vim.fn.getcwd() end,
            -- Additional Playwright options for better debugging
            get_playwright_binary = function()
              local uv = vim.uv or vim.loop
              return uv.cwd() .. "/node_modules/.bin/playwright"
            end,
            -- Filter test files
            filter_dir = function(name) return name ~= "node_modules" and name ~= ".git" end,
          },
        }),

        -- neotest-vim-test for test runners not available by default neotest
        require("neotest-vim-test")({ ignore_filetypes = { "python", "lua", "typescript", "javascript" } }),
      },
    })

    -- Keybinds
    vim.keymap.set("n", "<leader>nt", function() neotest.run.run(vim.fn.expand("%")) end, { desc = "Run File" })
    vim.keymap.set("n", "<leader>nT", function() neotest.run.run(vim.uv.cwd()) end, { desc = "Run All Test Files" })
    vim.keymap.set("n", "<leader>nr", function() neotest.run.run() end, { desc = "Run Nearest" })
    vim.keymap.set("n", "<leader>nl", function() neotest.run.run_last() end, { desc = "Run Last" })
    vim.keymap.set("n", "<leader>nd", function() neotest.run.run({ strategy = "dap" }) end, { desc = "Debug Nearest" })
    vim.keymap.set("n", "<leader>ns", function() neotest.summary.toggle() end, { desc = "Toggle Summary" })
    vim.keymap.set(
      "n",
      "<leader>no",
      function() neotest.output.open({ enter = true, auto_close = false }) end,
      { desc = "Show Output" }
    )
    vim.keymap.set("n", "<leader>nO", function() neotest.output_panel.toggle() end, { desc = "Toggle Output Panel" })
    vim.keymap.set("n", "<leader>nS", function() neotest.run.stop() end, { desc = "Stop" })
    vim.keymap.set("n", "<leader>nw", function() neotest.watch.toggle(vim.fn.expand("%")) end, { desc = "Toggle Watch" })
    vim.keymap.set("n", "[t", function() neotest.jump.prev({ status = "failed" }) end, { desc = "Previous failed test" })
    vim.keymap.set("n", "]t", function() neotest.jump.next({ status = "failed" }) end, { desc = "Next failed test" })

    -- Playwright-specific keybindings
    vim.keymap.set(
      "n",
      "<leader>nph",
      function() neotest.run.run({ extra_args = { "--headed" } }) end,
      { desc = "Run Nearest (Headed)" }
    )

    vim.keymap.set("n", "<leader>npi", function()
      neotest.run.run({
        env = { PWDEBUG = "1" }, -- Opens Playwright Inspector
      })
    end, { desc = "Run with Playwright Inspector" })

    vim.keymap.set("n", "<leader>npt", function()
      neotest.run.run({
        extra_args = { "--trace", "on" },
      })
      vim.notify("Test run with trace recording. Use 'npx playwright show-trace' to view.", vim.log.levels.INFO)
    end, { desc = "Run with Trace" })

    vim.keymap.set("n", "<leader>npD", function()
      neotest.run.run({
        extra_args = { "--debug" }, -- Uses Playwright's native debugger
      })
    end, { desc = "Debug with Playwright Debugger" })

    -- Playwright CLI shortcuts (secured with path validation)
    local playwright = require("utils.playwright")

    vim.keymap.set(
      "n",
      "<leader>npc",
      function() playwright.execute_playwright_command({ "codegen" }) end,
      { desc = "Open Playwright Codegen" }
    )

    vim.keymap.set(
      "n",
      "<leader>npv",
      function() playwright.execute_playwright_command({ "show-trace" }) end,
      { desc = "Open Trace Viewer" }
    )

    -- Playwright DAP debugging with full security validation
    -- Uses utils.playwright for secure test name extraction and command execution
    vim.keymap.set("n", "<leader>npd", playwright.debug_test_at_cursor, { desc = "Debug Playwright Test with DAP" })
  end,
}
