# dotfiles (Omarchy)

Overrides for an [Omarchy](https://omarchy.org/) system, organized as opt-in
features that per-machine profiles select. See `README.md` for the layout.

Omarchy ships a Claude skill at `~/.claude/skills/omarchy/`. Use it for any
question about *what* to put in these configs (Hyprland bindings, bar widgets,
themes, hooks, `omarchy` commands). This file only covers the repo itself.

## Working here

- A feature is `features/<name>/`: `about`, and any of `hypr.lua`, `files/`,
  `linkdirs`, `packages`, `aur`, `setup`, `off`. Profiles in `profiles/` list
  feature names. `./install.sh` applies the current profile and must stay
  idempotent and quiet when nothing changes.
- Linked files are live: editing the repo copy edits the real config.
- `setup`/`off` are sourced by install.sh. Use its helpers (`run`, `say`,
  `ensure_line`, `remove_line`, `ensure_block`, `bar_set`, `bar_put`,
  `plugin_add`, `plugin_off`) and guard every action so a rerun
  does nothing. `$FEATURE` is the feature dir, and `$CHANGED` is 1 when its links
  just changed.
- Prefer Omarchy's own commands (`omarchy pkg add`, `omarchy bar set/put`,
  `omarchy plugin add`, `omarchy font set`, `omarchy hook install`, …) over
  editing their files.
- Never edit `/usr/share/omarchy/`. It's package-owned. Reading it is fine.
- Validate Hyprland changes with `hyprctl reload && hyprctl configerrors`
  (install.sh does this when a hypr file changed).

## Before adding a file to a feature

Omarchy layers some config and snapshots the rest:

- **Layered** (Hyprland via `hypr.lua`, `hooks/*.d/`, `themes/<name>/`,
  git `[include]`, a `source` line in `.bashrc`, `omarchy bar set`): Omarchy
  keeps its defaults, and the feature only adds. Prefer these.
- **Snapshot** (`starship.toml`, `hyprsunset.conf`, terminal configs, …):
  the feature's copy replaces Omarchy's. Put Omarchy's current default at the
  same path under `upstream/` so `./omarchy-diff` can merge later changes.

`diff /usr/share/omarchy/config/<path> ~/.config/<path>` first. If it matches
the default, it doesn't belong here. Keep files to the lines that actually
change something, without Omarchy's commented-out template examples.

## Not in scope

`main` is the archived pre-Omarchy setup (the `quill` Go CLI). Don't port its
patterns here.
