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
- `features/nvim/.../lazy-lock.json` is tracked: it pins plugin commits so
  `:Lazy restore` has a known-good point. lazy rewrites it on every install or
  update, so commit it with any nvim change.
- Neovim changes update the cheatsheet (`features/nvim/.../lua/cheatsheet/`),
  which `<leader>?` and `:Cheatsheet html` render from live keymaps plus two
  hand-written files. Every new map gets a `desc`. A new key prefix gets an
  entry in `groups.lua`; a new, removed or reworked feature gets its
  `features.lua` entry kept current. Before committing:
  `nvim --headless <some file> +'Cheatsheet check' +qa`.
- `~/.claude/settings.json` is deliberately untracked: the work machine keeps
  its own. Don't add one under `features/claude/files/`.
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
