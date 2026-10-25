-- C# via Microsoft's Roslyn language server (the one VS Code uses). Replaced
-- csharp_ls (2026-10-15): one server for all .cs, and the Unity package
-- (features/unity) generates the .sln/.csproj Roslyn wants. The server itself
-- comes from Mason (mason.lua); this plugin only starts and targets it.
-- Server settings live in after/lsp/roslyn.lua.
return {
  "seblyng/roslyn.nvim",
  ft = "cs",
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  opts = {},
}
