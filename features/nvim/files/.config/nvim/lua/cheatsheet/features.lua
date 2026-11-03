-- Hand-written tour of what this config does and why. Shown on the Features
-- page of <leader>? (Tab flips pages) and :Cheatsheet html.
--
-- `keys` are looked up in the live keymaps at render time so the desc stays
-- current and a key that disappears is flagged. A second element is a
-- fallback desc for maps that only exist in some buffers (LSP, gitsigns,
-- filetype plugins); without one, a missing key renders as "unmapped".
return {
  -- navigation ---------------------------------------------------------
  {
    title = "Harpoon",
    tag = "navigation",
    summary = "Four pinned files per project, one chord each.",
    body = [[Pin the handful of files you keep bouncing between and jump to them with M-h/j/k/l from anywhere, including a terminal or the tree. The list is per working directory and survives restarts. C-e shows the list to reorder or prune it.]],
    keys = { "<leader>ma", "<C-e>", "<M-h>", "<M-j>", "<M-k>", "<M-l>" },
  },
  {
    title = "Snacks pickers",
    tag = "navigation",
    summary = "One fuzzy picker for files, grep, git, LSP, help and more.",
    body = [[Space Space is the smart file picker (recent plus project files). Slash greps the project, comma lists buffers. The s prefix holds the rest: help pages, keymaps, diagnostics, undo history, registers. R resumes the last picker. Inside a picker, C-q sends results to the quickfix list.]],
    keys = { "<leader><Space>", "<leader>/", "<leader>,", "<leader>sk", "<leader>sh", "<leader>su", "<leader>sR" },
  },
  {
    title = "Treesitter textobjects",
    tag = "navigation",
    summary = "Functions, classes and parameters as motions and selections.",
    body = [[af/if, ac/ic and aa/ia select around or inside a function, class or parameter in any language with a parser, so `daa` deletes an argument and `vif` selects a body. ]f and [f jump between function starts, ]c and [c between classes. an and in grow or shrink a selection by syntax node.]],
    keys = { { "af", "Around function" }, { "ia", "Inside parameter" }, { "]f", "Next function start" }, { "an", "Select parent node" } },
  },
  {
    title = "tmux-aware window moves",
    tag = "navigation",
    summary = "C-h/j/k/l cross between nvim splits and tmux panes.",
    body = [[vim-tmux-navigator makes the same four chords move focus across nvim windows and tmux panes as if they were one grid. This is why C-l is taken, and why Esc clears search highlight instead.]],
    keys = {},
  },
  {
    title = "Centered paging and search",
    tag = "navigation",
    summary = "C-d, C-u, n and N keep the cursor line in the middle.",
    body = [[Half-page scrolls and search jumps recenter the screen so you never land on the last visible line. hlslens shows a match counter next to the cursor after n, N, * and #. Esc clears the highlight.]],
    keys = { "<C-d>", { "n", "Next match (centered, lens)" }, { "*", "Search word under cursor forward" }, { "<Esc>", "Clear search highlight and multicursors" } },
  },
  {
    title = "Snacks words",
    tag = "navigation",
    summary = "Jump between references to the symbol under the cursor.",
    body = [=[The LSP highlights other uses of the current symbol; ]] and [[ step through them. Works in terminals too, for plain word matches.]=],
    keys = { "]]", "[[" },
  },

  -- editing ------------------------------------------------------------
  {
    title = "mini.surround",
    tag = "editing",
    summary = "Add, delete and replace brackets, quotes, tags and calls.",
    body = [[sa + textobject + char adds a surrounding (saiw" quotes the word). sd and sr delete and replace. Characters: ( [ { < add a space, ) ] } > do not, b and q mean any bracket or quote, f is a function call, t a tag, ? prompts for both sides. In visual mode, sa wraps the selection.]],
    keys = { "sa", "sd", "sr" },
  },
  {
    title = "Multicursor (0.13+)",
    tag = "editing",
    when = function() return vim.fn.has("nvim-0.13") == 1 end,
    summary = "Neovim's builtin multiple cursors with leader-k aliases.",
    body = [[Place cursors, then edit once: normal commands, mappings, insert text and even mini.surround replay at every cursor. ks puts a cursor on every search match, kw on every word, kl (visual) on every selected line. Follow mode (kf) makes cursor-relative motions replay too. Esc clears. The builtin keys Q, zq, q= and gQ still work.]],
    keys = { "<leader>ka", "<leader>ks", "<leader>kw", "<leader>kf", "<leader>kc" },
  },
  {
    title = "Completion and snippets",
    tag = "editing",
    summary = "blink.cmp with LuaSnip, friendly-snippets and Emmet.",
    body = [[Nothing is preselected: Enter accepts only an item you have moved to, Tab accepts the top item, C-space opens the menu or docs, C-e hides it. Signature help pops up as you type arguments. Snippets expand with C-l and jump with C-l / C-h; C-j cycles choice nodes. Custom snippets live in snippets/ (VS Code JSON) and lua/snippets/. The Unity snippet set is loaded into C# buffers.]],
    keys = { { "<C-l>", "Expand or jump to next snippet node" }, { "<C-h>", "Jump to previous snippet node" }, { "<C-j>", "Cycle through snippet choices" } },
  },
  {
    title = "Auto pairs",
    tag = "editing",
    summary = "mini.pairs closes brackets and quotes as you type.",
    body = [[Typing an opener inserts the closer; typing the closer over it steps past; Backspace removes both; Enter inside a pair opens a block.]],
    keys = {},
  },
  {
    title = "Line and clipboard helpers",
    tag = "editing",
    summary = "The small keys that add up.",
    body = [[J and K in visual move the selection and reindent. Normal J joins without moving the cursor. A-o opens a line above from insert mode and A-; appends a semicolon without leaving the line. Leader y and Y yank to the system clipboard, leader p pastes over a selection without clobbering the register, leader D deletes without yanking.]],
    keys = { "J", "<M-;>", "<M-o>", "<leader>y", "<leader>p", "<leader>D" },
  },
  {
    title = "Format and lint",
    tag = "editing",
    summary = "conform formats on save; nvim-lint runs on open, save and insert leave.",
    body = [[prettier, stylua, black + isort, rubocop, goimports + gofumpt, clang-format, chosen by filetype. Format-on-save can be toggled per session; cf formats a file or a visual range on demand. pylint and golangci-lint run automatically and feed diagnostics; cl reruns them.]],
    keys = { { "<leader>cf", "Format file or range" }, { "<leader>ct", "Toggle format on save" }, { "<leader>cl", "Lint file" } },
  },
  {
    title = "Persistent undo and undo picker",
    tag = "editing",
    summary = "Undo history survives closing the file.",
    body = [[undofile is on, so u works across sessions. The undo picker shows the tree with diffs, for the "what did I change an hour ago" case.]],
    keys = { "<leader>su" },
  },

  {
    title = "Treesitter",
    tag = "editing",
    summary = "Parsers for ~30 languages; highlighting, indentation, tag closing.",
    body = [[The main branch of nvim-treesitter installs a fixed parser list on first run and :TSUpdate keeps them current. Highlighting is on everywhere a parser exists; indentation is handed to treesitter only for languages that ship an indent query (C# keeps Vim's). nvim-ts-autotag closes and renames HTML, JSX and Vue tags as you type.]],
    keys = {},
  },
  {
    title = "Indent detection",
    tag = "editing",
    summary = "vim-sleuth sets shiftwidth and expandtab from the file.",
    body = [[The default is four spaces, but opening a file that uses tabs or two spaces switches the buffer to match, so edits never mix styles.]],
    keys = {},
  },
  -- code ---------------------------------------------------------------
  {
    title = "LSP",
    tag = "code",
    summary = "Mason-installed servers, Neovim 0.11+ defaults, pickers for gotos.",
    body = [[lua_ls, ts_ls, html, cssls, emmet, pyright, eslint, ruby_lsp, gopls, clangd, plus Roslyn for C#. gd, gD, grr, gri, grt and gO open Snacks pickers; grn renames, gra lists code actions, K hovers. [d and ]d step diagnostics, cd shows the line's diagnostics in a float. cS restarts the attached servers when one wedges.]],
    keys = { "gd", "grr", "gO", { "<leader>cd", "Show line diagnostics" }, { "<leader>cs", "Signature help" }, { "<leader>cS", "Restart LSP" }, "<leader>sd" },
  },
  {
    title = "C# via Roslyn",
    tag = "code",
    summary = "The same language server VS Code uses, pointed at the project's .sln.",
    body = [[roslyn.nvim starts Mason's roslyn-language-server for every .cs buffer and picks the solution in the project root.]],
    keys = {},
  },
  {
    title = "Lua development",
    tag = "code",
    summary = "lazydev gives lua_ls the Neovim API and plugin types.",
    body = [[Editing this config gets completion and hover for vim.* and for any plugin whose types lazydev can find. fc opens a picker scoped to the config directory.]],
    keys = { "<leader>fc" },
  },
  {
    title = "Todo comments",
    tag = "code",
    summary = "TODO, FIXME, HACK, WARN, NOTE, PERF and TEST highlighted and searchable.",
    body = [[Keywords are highlighted in comments. st lists every one in the project; the second map narrows to TODO/FIX/FIXME.]],
    keys = { "<leader>st" },
  },

  -- testing and debugging ---------------------------------------------
  {
    title = "Neotest",
    tag = "testing",
    summary = "Run the nearest test, file or suite; watch mode; jump to failures.",
    body = [[Adapters for pytest, vitest, Playwright, dotnet (vstest), plenary and vim-test fallbacks. nr runs the test under the cursor, nt the file, nT everything. ns opens the summary tree, no the output of the current test, nw reruns on save. [t and ]t jump between failed tests. nd runs the nearest test under the debugger.]],
    keys = { "<leader>nr", "<leader>nt", "<leader>ns", "<leader>no", "<leader>nw", "]t", "<leader>nd" },
  },
  {
    title = "Playwright",
    tag = "testing",
    summary = "Neotest runs with the flags that matter for browser tests.",
    body = [[Headed, inspector (PWDEBUG), trace on, and the rest under np. The Playwright DAP config is only registered when playwright is installed in the workspace.]],
    keys = { "<leader>nph", "<leader>npi", "<leader>npt" },
  },
  {
    title = "Debugger",
    tag = "debug",
    summary = "nvim-dap with dap-ui, virtual text and adapters for Python, Node, Go, .NET and C/C++.",
    body = [[F5 continues (or starts), F7/F8/F9 step over, into and out. db toggles a breakpoint, dL sets a log point. du opens the UI; dh and dP inspect the expression under the cursor. Go configs key off the current file so multi-module repos work. C and C++ use gdb's native DAP: a loose .cpp is compiled with debug info into the cache dir and run, with stdout line-buffered so output appears as you step.]],
    keys = { "<F5>", "<F8>", "<leader>db", "<leader>du", "<leader>dh", "<leader>dL" },
  },

  -- git ----------------------------------------------------------------
  {
    title = "Git hunks",
    tag = "git",
    summary = "gitsigns in the gutter; stage, reset, preview and blame per hunk.",
    body = [[The current line shows author, date and summary at end of line after a short pause (ghtb turns it off). ]h and [h move between hunks, ih selects one as a textobject. ghs stages, ghr resets, ghp previews inline, ghb shows the full blame for the line. ghd diffs against the index, ghq leaves diff mode; ghtd and ghtw toggle deleted lines and word diff.]],
    keys = { { "]h", "Next hunk" }, { "<leader>ghs", "Stage hunk" }, { "<leader>ghp", "Preview hunk" }, { "<leader>ghb", "Blame line" }, { "<leader>ghtb", "Toggle line blame" } },
  },
  {
    title = "Git pickers and lazygit",
    tag = "git",
    summary = "Branches, log, status, stash and diff as pickers; lazygit in a float.",
    body = [[gg opens lazygit. gl and gf show the log for the repo or the current file, gL for the current line. gs is a status picker, gd a hunk picker, gB opens the file on the forge in the browser.]],
    keys = { "<leader>gg", "<leader>gl", "<leader>gs", "<leader>gB" },
  },

  -- notes and docs -----------------------------------------------------
  {
    title = "Obsidian vaults",
    tag = "notes",
    summary = "obsidian.nvim over ~/vaults/Personal and ~/vaults/Work.",
    body = [[Loads only for files under ~/vaults. of finds a note, os searches full text, on creates one, ot inserts a template. ob and ol list backlinks and outgoing links, ok links the selection, oe extracts it into a new note, op pastes an image. ow switches vault.]],
    keys = { "<leader>of", "<leader>os", "<leader>on", "<leader>ob", "<leader>ow" },
  },
  {
    title = "Markdown rendering",
    tag = "docs",
    summary = "markview renders in the buffer; peek previews in the browser.",
    body = [[Headings, tables, checkboxes and code blocks render in place (not in the vaults, where Obsidian's own rendering is enough). Diagram blocks stay as text: inline images need the kitty graphics protocol, which Windows Terminal lacks. mp opens a browser preview for long documents.]],
    keys = { { "<leader>mp", "Markdown preview (browser)" } },
  },
  {
    title = "Graph view for data files",
    tag = "docs",
    summary = "Videre draws JSON, YAML, TOML and XML as a node graph.",
    body = [[For a config or payload too nested to read as text. Opens on the current file.]],
    keys = { "<leader>uv" },
  },
  {
    title = "Database UI",
    tag = "docs",
    summary = "vim-dadbod-ui with SQL completion.",
    body = [[ed toggles the connection tree; run queries from a buffer and get results in a split. Completion reads the schema of the active connection.]],
    keys = { "<leader>ed" },
  },


  -- ui and theme -------------------------------------------------------
  {
    title = "Colorscheme from a staged theme spec",
    tag = "theme",
    summary = "The colorscheme comes from a tracked Omarchy-style neovim.lua, catppuccin by default.",
    body = [[There is no Omarchy here, so features/nvim/files/.local/state/omarchy/current/theme/neovim.lua stands in for the theme Omarchy would stage. Swap it for another theme's neovim.lua and the watcher applies it live; the transparency pass strips panel backgrounds again afterwards so the terminal shows through. uC previews any installed scheme without changing the file.]],
    keys = { "<leader>uC" },
  },
  {
    title = "Snacks UI pieces",
    tag = "ui",
    summary = "Notifier, indent guides, scope, zen, scratch, terminal, big-file mode.",
    body = [[Notifications stack top right and sn lists them. Indent guides and scope highlight are subtle on purpose. uz is zen mode, wz zooms a split. Dot toggles a scratch buffer per directory, C-/ a floating terminal. Files over the bigfile threshold open with treesitter and LSP off.]],
    keys = { "<leader>sn", "<leader>uz", "<leader>wz", "<leader>.", "<C-/>" },
  },
  {
    title = "Explorer",
    tag = "ui",
    summary = "nvim-tree, toggled on the current file.",
    body = [[ee toggles the tree, ef opens it with the current file revealed, ec collapses, er refreshes. Window picker is off so opening a file lands in the split you came from.]],
    keys = { "<leader>ee", "<leader>ef", "<leader>ec" },
  },
  {
    title = "Windows, tabs, quickfix",
    tag = "ui",
    summary = "Leader w, t and q groups; arrows resize.",
    body = [[wv/wh split, we equalises, wx closes, wo keeps only the current. tt/tc/tn/tp manage tab pages, tf opens the buffer in a new one. qo/qc open and close quickfix, [q and ]q walk it, qq lists it as a picker. C-arrows resize the current window.]],
    keys = { "<leader>wv", "<leader>wo", "<leader>tt", "<leader>qo", "<C-Up>" },
  },
  {
    title = "Statusline",
    tag = "ui",
    summary = "lualine with a macro-recording notice and an LSP client count.",
    body = [[The gear shows how many servers are attached to the buffer; :checkhealth lsp names them. Recording a macro shows the register while q is active.]],
    keys = {},
  },

  {
    title = "Colour swatches",
    tag = "ui",
    summary = "nvim-colorizer paints hex, rgb and Tailwind colours inline.",
    body = [[Every filetype, CSS functions and Tailwind class names included. A theme switch can leave stale swatches; ur resets the cache and reattaches.]],
    keys = { "<leader>ur" },
  },
  {
    title = "Which-key",
    tag = "ui",
    summary = "Pause after a prefix to see what follows.",
    body = [[Press Space (or g, [, ], s) and wait a moment for the popup. Group titles come from the cheatsheet's groups file, so the two never disagree.]],
    keys = {},
  },
  {
    title = "Editor defaults worth knowing",
    tag = "ui",
    summary = "The options that change how the editor feels.",
    body = [[Relative line numbers. Command line hidden until used (cmdheight 0). Rounded borders on every float. Substitutions preview in a split as you type (inccommand). Ten lines of scroll margin. Tabs and trailing spaces drawn as » and ·. Search ignores case unless you type a capital. New splits open right and below. No swap or backup files; undo history lives in ~/.vim/undodir. Yanked text flashes. Reopening a file restores the cursor. q closes help, quickfix and man windows. Markdown gets conceallevel 2.]],
    keys = {},
  },
  {
    title = "Plugin management",
    tag = "ui",
    summary = "lazy.nvim on latest, with an update checker; roll back one plugin from its reflog.",
    body = [[:Lazy opens the manager; the checker notifies when updates are available. lazy-lock.json is local only (untracked). If a plugin misbehaves after an update, `git -C ~/.local/share/nvim/lazy/<plugin> reflog` shows where each update moved it: HEAD@{1} is the version before the last update. Pin that with commit = "<sha>" in its spec, :Lazy update <plugin>, and drop the pin once upstream is fixed. If nvim itself broke, `bob rollback` returns to the previous nightly. sp fuzzy-finds a plugin's spec.]],
    keys = { "<leader>sp" },
  },
  -- shell --------------------------------------------------------------
  {
    title = "sdev",
    tag = "shell",
    summary = "Pick a project with zoxide, get a tmux session with ai, nvim and term windows.",
    body = [[From any shell, sdev fuzzy-picks a directory from zoxide's history and opens (or switches to) a tmux session named after it, with an ai window, an nvim window already running `nvim .`, and a term window. Lives in features/basics/bash/personal.]],
    keys = {},
    see = "features/basics/bash/personal",
  },
  {
    title = "Neovim versions with bob",
    tag = "shell",
    summary = "Stable and nightly side by side; bob use swaps.",
    body = [[bob (from mise) installs builds under ~/.local/share/bob and its shim sits first in PATH when present. The nvim feature selects nightly; `bob use stable` switches back, and `bob update nightly` pulls a newer snapshot.]],
    keys = {},
  },
}
