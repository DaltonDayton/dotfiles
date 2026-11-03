# dotfiles (wsl branch)

Terminal-only config for Ubuntu 24.04 or 26.04 under WSL, organized as opt-in features
that a profile selects. See `README.md` for the layout. There is no desktop,
window manager, or Omarchy on this machine; `features/basics/bash/` is a
one-time snapshot of Omarchy's shell defaults and is edited directly.

## Working here

- A feature is `features/<name>/`: `about`, and any of `files/`, `linkdirs`,
  `packages` (apt), `mise`, `setup`, `off`. Profiles in `profiles/` list
  feature names. `./install.sh` applies the current profile and must stay
  idempotent and quiet when nothing changes.
- Linked files are live: editing the repo copy edits the real config.
- Neovim changes update the cheatsheet (`features/nvim/.../lua/cheatsheet/`),
  which `<leader>?` and `:Cheatsheet html` render from live keymaps plus two
  hand-written files. Every new map gets a `desc`, or it is invisible there.
  A new key prefix gets an entry in `groups.lua` (title, blurb; which-key
  reads its groups from the same file). A new, removed or reworked feature
  gets its `features.lua` entry added, dropped or rewritten, with the keys it
  references kept current: a listed key that no longer exists renders as
  "unmapped". Before committing, open a file and run `:Cheatsheet check`, or
  headless: `nvim --headless <some file> +'Cheatsheet check' +qa`.
- Neovim runs bob's nightly and every plugin on latest; `lazy-lock.json` is
  untracked. When something breaks after an update, find what moved first:
  each plugin clone's reflog (`git -C ~/.local/share/nvim/lazy/<plugin>
  reflog`) shows its updates, and `HEAD@{1}` is the version before the last
  one. Suggest rolling the suspect back to that (pin `commit = "<sha>"` in its
  spec, `:Lazy update <plugin>`, drop the pin once fixed) rather than the
  previous commit, since one update can span many commits. If nvim itself is
  the suspect, `bob rollback` returns to the previous nightly.
- `~/.claude/settings.json` and the global `~/.claude/CLAUDE.md` are deliberately
  untracked: they carry machine-specific content. Don't add them under
  `features/claude/files/`.
- `setup`/`off` are sourced by install.sh. Use its helpers (`run`, `say`,
  `ensure_line`, `remove_line`, `ensure_block`, `remove_block`) and guard every
  action so a rerun does nothing. `$FEATURE` is the feature dir, `$STATE` is
  `~/.local/state/dotfiles`, and `$CHANGED` is 1 when its links just changed.
- Prefer apt for a tool when Ubuntu's version is recent enough, and mise
  otherwise (its registry covers most CLI tools; `mise registry | grep name`).
- Keep files to the lines that actually change something.

## Not in scope

`main` is the Omarchy setup for the personal machines and `quill` is the
archived pre-Omarchy one. Don't port patterns from either here; this branch is
managed on its own.
