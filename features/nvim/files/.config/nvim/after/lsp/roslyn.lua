-- Unity's Neovim package starts nvim with --cmd globals carrying the
-- diagnostic scopes chosen in its settings window; outside Unity they are nil
-- and Roslyn's default (openFiles) applies.
return {
  settings = {
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = _G.nvim_unity_analyzer_diagnostic_scope,
      dotnet_compiler_diagnostics_scope = _G.nvim_unity_compiler_diagnostic_scope,
    },
    ["csharp|inlay_hints"] = {
      csharp_enable_inlay_hints_for_implicit_object_creation = true,
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
    },
  },
}
