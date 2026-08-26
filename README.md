# dotfiles

Personal configuration for [Omarchy](https://omarchy.org/) (Arch + Hyprland).

Omarchy ships its defaults in `/usr/share/omarchy/`. This repo holds only what
sits on top of them, plus the configs Omarchy doesn't manage (neovim, tmux,
opencode, Claude Code).

## Install

```sh
git clone git@github.com:DaltonDayton/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry   # preview
./install.sh
```

`install.sh` symlinks `config/*` into `~/.config/` and `home/*` into `~/`, one
file at a time, so Omarchy's own tooling (the monitor wizard, the bar editor)
writes straight back into this repo and its edits show up as diffs. Anything
real already sitting at a target is moved aside to `<file>.bak.<epoch>` first.
Rerunning is a no-op.

`config/nvim` is linked as a whole directory instead of file-by-file, because
lazy.nvim writes into it.

## Adopting things one at a time

Most of what was carried over from the old setup is **staged, not live**. It sits
in the repo so it's there to pick from, and `install.sh`'s `PENDING` list keeps
it unlinked:

| Staged | Would replace |
|---|---|
| `config/tmux/tmux.conf` | Omarchy's default tmux config |
| `config/opencode/*.json` | Omarchy's default opencode config |
| `config/sesh/sesh.toml` | nothing — new file |
| `home/.claude/{CLAUDE.md,rules,stacks}` | nothing — new files |
| `config/git/personal` | nothing — layers in via `[include]` |
| `home/.zshrc` | nothing until you `chsh` to zsh |

To adopt one: delete its line from `PENDING` in `install.sh`, then rerun. To see
what you'd be taking on first:

```sh
diff /usr/share/omarchy/config/tmux/tmux.conf config/tmux/tmux.conf
```

Currently live: `config/nvim`, plus the `config/hypr/` and `config/omarchy/`
files — those are snapshots of what was already on the system, so linking them
changed no behavior, it just put them under version control.

## What's tracked, and what isn't

Omarchy layers config in two different ways, and only one of them is safe to
keep in git.

**Layered** — upstream owns the defaults, your file holds only overrides. These
are tracked, because they can't go stale:

| Path | How it layers |
|---|---|
| `config/hypr/*.lua` | `hyprland.lua` requires `default.hypr.omarchy`, then your files |
| `config/omarchy/hooks/*.d/*.hook` | additive drop-in directories |
| `config/omarchy/defaults/` | single-value files read by `omarchy` commands |
| `config/git/personal` | pulled into Omarchy's git config by an `[include]` |

**Snapshots** — your file replaces the default outright. Tracked only where the
file is authoritative by design anyway:

- `config/omarchy/shell.json` — once you customize the bar, Omarchy stops
  merging its defaults back in (by design), so a tracked copy costs nothing.
- `config/omarchy/shell.toml` — small, entirely yours.

Everything else that's a plain copy of an upstream default is deliberately
**not** tracked: `starship.toml`, `btop.conf`, `lazygit/config.yml`,
`omarchy-menu.jsonc`, `omarchy/branding/`, and the terminal configs. Committing
those pins a stale version of a file Omarchy will keep improving.

## Set by command, not tracked

These live in Omarchy's own state, so reproduce them by running the command
rather than restoring a file:

```sh
omarchy theme set catppuccin
omarchy font set "CaskaydiaMono Nerd Font"   # rewrites all four terminal configs
```

Background: `3-blue-eye.png` (from the catppuccin theme).

Commit signing needs an untracked `~/.config/git/config.local` with
`user.signingkey` and `commit.gpgsign`; `config/git/personal` includes it.

## Layout

| Path | Goes to |
|---|---|
| `config/hypr/` | `~/.config/hypr/` |
| `config/omarchy/` | `~/.config/omarchy/` |
| `config/nvim/` | `~/.config/nvim/` |
| `config/{tmux,sesh,opencode}/` | *(staged — see above)* |
| `config/git/personal` | *(staged — applied by `[include]`, not a symlink)* |
| `home/.claude/` | *(staged)* |
| `home/.zshrc` | *(staged — currently on bash)* |

## History

The `main` branch holds the previous setup: `quill`, a Go CLI that managed
packages, modules, and profiles declaratively. Omarchy covers that ground, so
this branch starts fresh. `main` is kept as an archive — pull anything else
across with `git restore --source=main -- <path>`.
