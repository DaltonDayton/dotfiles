# dotfiles (Omarchy)

Overrides for an [Omarchy](https://omarchy.org/) system, organized as opt-in
features that per-machine profiles select. See `README.md` for the layout.

Omarchy ships a Claude skill at `~/.claude/skills/omarchy/`. Use it for any
question about *what* to put in these configs (Hyprland bindings, bar widgets,
themes, hooks, `omarchy` commands). This file only covers the repo itself.

## Why it's shaped this way

This repo is a diff against Omarchy, not a config. Omarchy owns the defaults
and keeps updating them; every file here should be justifiable as "this line
differs from stock and I know why".

- A feature is one user-visible effect, named by that effect (`lid-hibernate`,
  not `systemd-logind`). Group tiny related tweaks (`hypr-tweaks`, `basics`)
  instead of making a feature per line.
- Profiles are the only machine-specific thing. A new machine is a new profile
  picking from the same features. No host conditionals inside a feature.
- Dropping a feature from a profile must fully undo it, so prefer mechanisms
  that layer over Omarchy's files and can be reversed (see below).
- Some things stay manual on purpose: third-party plugins that run unsandboxed,
  tray pins, signing keys. When automating something needs sudo or a script we
  don't control, lean toward the README's "By hand" list instead.

## Working here

- A feature is `features/<name>/`: `about`, and any of `hypr.lua`, `files/`,
  `linkdirs`, `packages`, `aur`, `setup`, `off`. Profiles in `profiles/` list
  feature names. `./install.sh` applies the current profile and must stay
  idempotent and quiet when nothing changes.
- Linked files are live: editing the repo copy edits the real config. Edit the
  repo path, or use `sed -i --follow-symlinks`: plain `sed -i` replaces the
  symlink with a detached copy.
- `features/nvim/.../lazy-lock.json` is tracked: it pins plugin commits so both
  machines run the same set and `:Lazy restore` has a known-good point. lazy
  rewrites it on every install or update, so commit it with any nvim change,
  and on its own as `chore: bump nvim plugins` after a plain `:Lazy update`.
- `setup`/`off` are sourced by install.sh. Use its helpers (`run`, `say`,
  `ensure_line`, `remove_line`, `ensure_block`, `remove_block`, `bar_set`)
  and guard every action so a rerun
  does nothing. `$FEATURE` is the feature dir, and `$CHANGED` is 1 when its links
  just changed.
- Prefer Omarchy's own commands (`omarchy pkg add`, `omarchy bar set`,
  `omarchy font set`, `omarchy hook install`, …) over
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

The `quill` branch is the archived pre-Omarchy setup (the `quill` Go CLI). Don't port its
patterns here.
