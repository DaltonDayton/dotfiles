-- Unreal Engine integration: registers Neovim as the editor's source code
-- accessor and generates clangd files (compile_commands.json, .clangd) for
-- Unreal C++ projects via UnrealBuildTool. Inert on a machine without the
-- engine (cond below); the setup is in features/unreal/README.md.
--
-- The editor must be launched with <leader>Uo so it inherits $NVIM and can
-- route "open file" requests back to this instance. It runs ue-nested
-- (features/unreal) rather than the plugin's open(): the editor lives on its
-- own X server so Hyprland never tiles its windows.
--
-- Keys live under <leader>U; <leader>u is the UI Toggles group.
--
-- No `build` hook on purpose: the plugin treats any engine with Build.sh as a
-- source build and would try to recompile the whole editor. This is a binary
-- install, so the accessor plugin is built once with <leader>Up (RunUAT
-- BuildPlugin). It symlinks the result into Engine/Plugins/Developer, which
-- breaks UBT on this binary install (precompiled engine rules cannot include a
-- new engine plugin). Move the symlink to Engine/Plugins/Marketplace after each
-- <leader>Up; UBT compiles Marketplace plugin rules separately.
local engine_path = vim.fn.expand("~/software/UnrealEngine/5.8.3")

return {
  "mbwilding/UnrealEngine.nvim",
  cond = vim.fn.isdirectory(engine_path) == 1,
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>Ug", function() require("unrealengine.commands").generate_lsp() end, desc = "UnrealEngine: Generate LSP" },
    { "<leader>Ub", function() require("unrealengine.commands").build() end, desc = "UnrealEngine: Build" },
    { "<leader>Ur", function() require("unrealengine.commands").rebuild() end, desc = "UnrealEngine: Rebuild" },
    {
      "<leader>Uo",
      function()
        local up = require("unrealengine.helpers").get_uproject_path_info()
        if not up then return vim.notify("No .uproject in " .. vim.fn.getcwd(), vim.log.levels.ERROR) end
        vim.fn.jobstart({ "ue-nested", up.path }, { detach = true })
      end,
      desc = "UnrealEngine: Open Editor",
    },
    { "<leader>Uc", function() require("unrealengine.commands").clean() end, desc = "UnrealEngine: Clean" },
    { "<leader>Up", function() require("unrealengine.commands").build_plugin() end, desc = "UnrealEngine: Build Plugin" },
  },
  opts = {
    engine_path = engine_path,
    auto_generate = true,
    auto_build = false,
    build_type = "Development",
    with_editor = true,
    register_icon = true,
    register_filetypes = true,
    close_on_success = true,
  },
}
