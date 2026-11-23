-- C# via Microsoft's Roslyn language server (the one VS Code uses), in place
-- of csharp_ls. The server itself comes from Mason (mason.lua); this plugin
-- only starts and targets it. Server settings live in after/lsp/roslyn.lua.
return {
  "seblyng/roslyn.nvim",
  ft = "cs",
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  opts = {},
}
