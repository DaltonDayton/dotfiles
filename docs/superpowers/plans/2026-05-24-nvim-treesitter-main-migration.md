# nvim-treesitter master → main branch migration

## Context

`nvim-treesitter` `master` is archived. `main` (v1.0) is a rewrite with a different API. Current config (`modules/neovim/files/nvim/lua/plugins/treesitter.lua`) uses `master` plus a hand-written compat shim that wraps `vim.treesitter.query.add_directive` / `add_predicate` to handle the `TSNode[]` vs `TSNode` callback signature change in Neovim 0.12.

User-confirmed scope:
- Migrate now.
- Keep `windwp/nvim-ts-autotag` (already separate plugin).
- Drop `textobjects` (af/if/ac/ic/aa/ia/]f/[f/]c/[c).
- Drop `incremental_selection` (`<leader>vi`/`vn`/`vb`).
- Drop the compat shim.

## End state

`modules/neovim/files/nvim/lua/plugins/treesitter.lua` looks roughly like:

```lua
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  dependencies = { "windwp/nvim-ts-autotag" },
  config = function()
    local parsers = {
      "bash", "c", "c_sharp", "css", "diff", "dockerfile",
      "embedded_template", "gitignore", "go", "gomod", "gosum",
      "html", "javascript", "json", "lua", "markdown", "markdown_inline",
      "python", "query", "regex", "ruby", "sql", "tsx",
      "typescript", "vim", "vimdoc", "yaml",
    }

    require("nvim-treesitter").install(parsers)

    local filetypes = {
      "bash", "c", "cs", "css", "diff", "dockerfile",
      "eruby", "gitignore", "go", "gomod", "gosum",
      "html", "javascript", "json", "lua", "markdown",
      "python", "query", "ruby", "sh", "sql",
      "typescript", "typescriptreact", "vim", "help", "yaml",
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
```

Key notes:
- `markdown_inline`, `regex`, `query` parsers are injection/util — no FileType pattern needed for `vim.treesitter.start()` on those.
- Filetype list maps from parser names: `c_sharp` → `cs`, `tsx` → `typescriptreact`, `vimdoc` → `help`, `bash` → `bash`/`sh`, `embedded_template` → `eruby`.
- Folding via TS is OPT-IN here (set per FileType). Was implicit before.
- `nvim-ts-autotag` setup is now called explicitly (master version was driven by `autotag = { enable = true }` inside `configs.setup`).

## Execution steps

1. **Snapshot lazy state.** Note current `lazy-lock.json` commit for `nvim-treesitter` (so rollback is possible).

2. **Rewrite `modules/neovim/files/nvim/lua/plugins/treesitter.lua`** to the end-state spec above.
   - Removes: `master` branch pin, textobjects dep, compat shim wrapping `add_directive`/`add_predicate`, `incremental_selection` block, `textobjects` block, `auto_install = false`.
   - Adds: `branch = "main"`, FileType autocmd, explicit autotag setup.

3. **Update lazy + sync parsers.** First `nvim` launch will:
   - lazy detects branch change, checks out `main`.
   - `build = ":TSUpdate"` re-runs (or `install()` call installs missing parsers on startup).
   - Existing parsers compiled against master ABI may still work; if not, `:TSUpdate` rebuilds.

4. **Verify.**
   - `:checkhealth nvim-treesitter` — should pass, no "ABI mismatch" errors.
   - Open a `.go`/`.lua`/`.py`/`.ts` file → highlights present.
   - `:TSPlayground` / `:InspectTree` → tree renders.
   - `<leader>vi` (incremental_selection) → should fail / no-op. Expected.
   - `vif` / `daf` (textobjects) → should fail. Expected.
   - Open `.html` → type `<div`, `>` → autotag inserts `</div>`. Expected.

5. **If broken: rollback.**
   - `git checkout HEAD~1 -- modules/neovim/files/nvim/lua/plugins/treesitter.lua`
   - `:Lazy sync` to restore master branch.
   - Parsers may need `:TSUpdate` again.

6. **Commit.** Single commit: `migrate nvim-treesitter to main branch`.

## Risks

- **First startup compiles parsers.** Could take 30s–2min depending on which parsers need rebuilding. User sees a delay, not a failure.
- **Some parsers may not exist on main's registry.** Unlikely for the listed set (all standard). If one fails, `install()` logs an error but keeps going.
- **`indentexpr` for non-TS contexts.** Treesitter indent isn't always great. If indentation regresses for a filetype, remove that filetype from the `filetypes` list (highlight stays, indent reverts to nvim default).
- **autotag plugin version compat with main branch nvim-treesitter.** `windwp/nvim-ts-autotag` has its own internals; latest release should work. If autotag breaks, pin to a known-good tag.

## Out of scope

- Removing the `lazy-lock.json` entry (lazy handles this).
- Migrating to alternate plugins (snacks-ts, etc.).
- Reintroducing textobjects or incremental_selection in any form.
