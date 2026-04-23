-- ============================================================================
-- Playwright Testing Utilities for Neovim
-- ============================================================================
-- Provides secure, testable utilities for Playwright test execution and debugging
-- Security: All user input and external data is validated before shell execution
-- ============================================================================

local M = {}

-- ============================================================================
-- SECURITY: Test Name Validation and Escaping
-- ============================================================================

--- Validates and escapes a test name for safe use in shell commands
--- Uses permissive validation: allows most characters but escapes shell-dangerous ones
--- @param name string The test name extracted from code
--- @return string|nil Escaped test name, or nil if validation fails
function M.validate_test_name(name)
  if not name or type(name) ~= "string" then return nil end

  -- SECURITY: Length validation to prevent DoS
  if #name > 200 then
    vim.notify("Test name exceeds maximum length (200 chars)", vim.log.levels.ERROR)
    return nil
  end

  -- SECURITY: Reject null bytes and control characters
  if name:match("%z") or name:match("[\1-\31]") then
    vim.notify("Test name contains invalid control characters", vim.log.levels.ERROR)
    return nil
  end

  -- SECURITY: Reject path traversal sequences
  if name:match("%.%.") then
    vim.notify("Test name contains path traversal sequence", vim.log.levels.ERROR)
    return nil
  end

  -- SECURITY: Escape shell-dangerous characters for -g flag
  -- Permissive approach: allow most chars but escape dangerous ones
  -- Dangerous chars: " ' ` $ ; | & ( ) < > \ newline
  local escaped = name
    :gsub("\\", "\\\\") -- Backslash first
    :gsub('"', '\\"') -- Double quote
    :gsub("'", "\\'") -- Single quote
    :gsub("`", "\\`") -- Backtick
    :gsub("%$", "\\$") -- Dollar sign
    :gsub(";", "\\;") -- Semicolon
    :gsub("|", "\\|") -- Pipe
    :gsub("&", "\\&") -- Ampersand
    :gsub("%(", "\\(") -- Opening paren
    :gsub("%)", "\\)") -- Closing paren
    :gsub("<", "\\<") -- Less than
    :gsub(">", "\\>") -- Greater than
    :gsub("\n", " ") -- Newline to space

  return escaped
end

-- ============================================================================
-- SECURITY: File Path Validation
-- ============================================================================

--- Validates a file path for security (workspace boundary, test file pattern)
--- @param file_path string Absolute path to validate
--- @return string|nil Validated path, or nil if validation fails
function M.validate_file_path(file_path)
  if not file_path or type(file_path) ~= "string" then return nil end

  -- SECURITY: Length validation
  if #file_path > 500 then
    vim.notify("File path exceeds maximum length (500 chars)", vim.log.levels.ERROR)
    return nil
  end

  -- SECURITY: Resolve symlinks to prevent symlink attacks
  local uv = vim.uv or vim.loop
  local real_path = uv.fs_realpath(file_path)
  if not real_path then
    vim.notify("Invalid file path or file does not exist", vim.log.levels.ERROR)
    return nil
  end

  -- SECURITY: Ensure file is within workspace boundary
  local cwd = vim.fn.getcwd()
  if not real_path:match("^" .. vim.pesc(cwd)) then
    vim.notify("Security: File is outside current workspace. Refusing to execute.", vim.log.levels.ERROR)
    return nil
  end

  -- SECURITY: Validate file extension matches test pattern
  local valid_extensions = { "%.spec%.ts$", "%.spec%.js$", "%.test%.ts$", "%.test%.js$", "%.spec%.tsx$", "%.spec%.jsx$" }
  local is_test_file = false
  for _, pattern in ipairs(valid_extensions) do
    if real_path:match(pattern) then
      is_test_file = true
      break
    end
  end

  if not is_test_file then
    vim.notify("File does not appear to be a Playwright test file (expected .spec.ts, .test.js, etc.)", vim.log.levels.WARN)
    return nil
  end

  return real_path
end

-- ============================================================================
-- SECURITY: Playwright Binary Validation
-- ============================================================================

--- Validates Playwright binary location before execution
--- @return string|nil Absolute path to verified Playwright binary, or nil if validation fails
local function validate_playwright_binary()
  local uv = vim.uv or vim.loop
  local playwright_path = uv.cwd() .. "/node_modules/.bin/playwright"

  -- Check if binary exists and is executable
  if vim.fn.executable(playwright_path) ~= 1 then
    vim.notify(
      "Playwright binary not found or not executable at: " .. playwright_path .. "\nRun: npm install -D @playwright/test",
      vim.log.levels.ERROR
    )
    return nil
  end

  -- SECURITY: Verify symlink points to expected location (prevent binary hijacking)
  local real_path = uv.fs_realpath(playwright_path)
  if not real_path then
    vim.notify("Could not resolve Playwright binary path", vim.log.levels.ERROR)
    return nil
  end

  -- Verify it's actually within node_modules/playwright or node_modules/.bin
  if not real_path:match("node_modules/playwright") and not real_path:match("node_modules/%.bin") then
    vim.notify(
      "Security: Playwright binary points to unexpected location: "
        .. real_path
        .. "\nExpected location within node_modules/playwright",
      vim.log.levels.ERROR
    )
    return nil
  end

  return playwright_path
end

-- ============================================================================
-- SECURITY: Safe Command Execution
-- ============================================================================

--- Executes a Playwright command with security validation
--- @param cmd_args table Array of command arguments (e.g., {"codegen"} or {"show-trace"})
function M.execute_playwright_command(cmd_args)
  if not cmd_args or type(cmd_args) ~= "table" then
    vim.notify("Invalid command arguments", vim.log.levels.ERROR)
    return
  end

  -- SECURITY: Validate Playwright binary
  local playwright_path = validate_playwright_binary()
  if not playwright_path then return end

  -- SECURITY: Build command with proper escaping
  local cmd_parts = { vim.fn.fnameescape(playwright_path) }
  for _, arg in ipairs(cmd_args) do
    table.insert(cmd_parts, vim.fn.fnameescape(tostring(arg)))
  end

  local cmd = table.concat(cmd_parts, " ")
  vim.cmd("terminal " .. cmd)
end

-- ============================================================================
-- Enhanced Treesitter Test Name Extraction
-- ============================================================================

--- Finds Playwright test name at cursor using Treesitter
--- Supports: test(), test.only(), test.skip(), test.describe(), test.fixme()
--- Handles: template literals, nested structures, various string types
--- @param buf number Buffer number
--- @param cursor_line number Line number (1-indexed)
--- @return string|nil Test name or nil if not found
function M.find_test_at_cursor(buf, cursor_line)
  -- SECURITY: Validate inputs
  if not buf or not cursor_line then return nil end

  -- Try to get Treesitter parser
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then return nil end

  -- Parse the buffer
  local tree = parser:parse()[1]
  if not tree then return nil end

  local root = tree:root()

  -- Get node at cursor position
  -- SECURITY: Use actual line length instead of magic number
  local line_content = vim.api.nvim_buf_get_lines(buf, cursor_line - 1, cursor_line, false)[1]
  local line_length = line_content and #line_content or 999
  local node = root:descendant_for_range(cursor_line - 1, 0, cursor_line - 1, line_length)

  -- SECURITY: Limit traversal depth to prevent DoS on deeply nested structures
  local max_depth = 50
  local depth = 0

  -- Walk up the tree to find test context
  while node do
    depth = depth + 1
    if depth > max_depth then
      vim.notify("Test extraction exceeded maximum depth limit", vim.log.levels.WARN)
      return nil
    end

    if node:type() == "call_expression" then
      local func_node = node:field("function")[1]
      if func_node then
        local func_text = vim.treesitter.get_node_text(func_node, buf)

        -- Match all Playwright test function variants
        local is_test = func_text
          and (
            func_text:match("^test$")
            or func_text:match("^test%.only$")
            or func_text:match("^test%.skip$")
            or func_text:match("^test%.describe$")
            or func_text:match("^test%.fixme$")
            or func_text:match("^test%.fail$")
          )

        if is_test then
          local args = node:field("arguments")[1]
          if args then
            -- Extract first string argument
            local first_arg = nil
            for child in args:iter_children() do
              local child_type = child:type()
              if child_type == "string" or child_type == "template_string" or child_type == "string_fragment" then
                first_arg = child
                break
              end
            end

            if first_arg then
              local test_name = vim.treesitter.get_node_text(first_arg, buf)

              -- Handle different string types
              if first_arg:type() == "template_string" then
                -- Extract content between backticks, keep template expressions
                test_name = test_name:gsub("^`", ""):gsub("`$", "")
              elseif first_arg:type() == "string" then
                -- Remove quotes
                test_name = test_name:gsub("^[\"']", ""):gsub("[\"']$", "")
              elseif first_arg:type() == "string_fragment" then
                -- Already without quotes
              end

              return test_name
            end
          end
        end
      end
    end
    node = node:parent()
  end

  return nil
end

-- ============================================================================
-- DAP Debugging Integration
-- ============================================================================

--- Debugs the Playwright test at cursor position using DAP
--- Performs security validation on all inputs before launching debugger
function M.debug_test_at_cursor()
  local file_path = vim.fn.expand("%:p")
  local cursor_line = vim.fn.line(".")
  local buf = vim.api.nvim_get_current_buf()

  -- SECURITY: Validate file path
  local validated_path = M.validate_file_path(file_path)
  if not validated_path then return end

  -- Extract test name using Treesitter
  local test_name = M.find_test_at_cursor(buf, cursor_line)
  if not test_name then
    vim.notify("No Playwright test found at cursor", vim.log.levels.WARN)
    return
  end

  -- SECURITY: Validate and escape test name
  local escaped_name = M.validate_test_name(test_name)
  if not escaped_name then
    vim.notify("Test name failed security validation", vim.log.levels.ERROR)
    return
  end

  -- Notify user
  vim.notify("Debugging Playwright test: " .. test_name, vim.log.levels.INFO)

  -- Launch DAP debugger with secured parameters
  require("dap").run({
    type = "pwa-node",
    request = "launch",
    name = "Debug Playwright Test",
    runtimeExecutable = "npx",
    -- SECURITY: Test name is escaped, passed as separate array element (not concatenated)
    runtimeArgs = { "playwright", "test", "--headed", "--timeout", "0", "-g", escaped_name },
    -- SECURITY: Use relative path from validated absolute path
    args = { vim.fn.fnamemodify(validated_path, ":.") },
    cwd = vim.fn.getcwd(),
    console = "integratedTerminal",
    internalConsoleOptions = "neverOpen",
  })
end

return M
