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

## Packages

`packages.sh` holds the packages this setup needs on top of Omarchy's own, and
`install.sh` runs it last. It's also fine to run alone:

```sh
./packages.sh --dry   # what's missing
./packages.sh
```

Add to the `REPO_PKGS` / `AUR_PKGS` arrays as you pick things up. Installs go
through `omarchy-pkg-add` and `omarchy-pkg-aur-add` — Omarchy's own idempotent
wrappers over `pacman -S --needed` and `yay`, which re-check with `pacman -Q`
afterwards so a silent failure still exits nonzero. Nothing missing means no
work and no sudo prompt, so `./install.sh` stays safe to rerun blind.

Note that installing from the menu (Install → Package / AUR) records nothing —
Omarchy has no notion of "packages I chose". Anything you want on the next
machine has to be added here by hand.

## Adopting things one at a time

A few carry-overs from the old setup are **staged, not live**. They sit in the
repo so they're there to pick from, and `install.sh`'s `PENDING` list keeps
them unlinked:

| Staged | Would replace |
|---|---|
| `config/sesh/sesh.toml` | nothing — new file, and `sesh` isn't installed yet |
| `home/.claude/{CLAUDE.md,rules,stacks}` | nothing — new files |

To adopt one: delete its line from `PENDING` in `install.sh`, then rerun. If
it would replace an Omarchy default, see what you'd be taking on first:

```sh
diff /usr/share/omarchy/config/<path> config/<path>
```

The old tmux, opencode, and zsh configs were staged here for a while and then
dropped: each would have replaced an Omarchy default wholesale, and the only
parts worth keeping (a couple of shell functions and aliases) were ported into
`home/.bashrc`. They're still in history if a piece is ever needed:

```sh
git log --diff-filter=D --oneline -- config/tmux config/opencode home/.zshrc
git restore --source=<that commit>^ -- config/tmux/tmux.conf
```

Currently live: `config/nvim`, `home/.bashrc`, `config/git/personal` (via the
`[include]`), and the `config/hypr/` and `config/omarchy/` files. The hypr and
omarchy files started as copies of what was on the system and now carry the
actual overrides: window rules, extra bindings, cursor theme, idle inhibitor,
bar layout.

## What's tracked, and what isn't

Omarchy layers config in two different ways, and only one of them is safe to
keep in git.

**Layered** — upstream owns the defaults, your file holds only overrides. These
are tracked, because they can't go stale:

| Path | How it layers |
|---|---|
| `config/hypr/*.lua` | `hyprland.lua` requires `default.hypr.omarchy`, then your files |
| `config/omarchy/defaults/` | single-value files read by `omarchy` commands |
| `config/git/personal` | pulled into Omarchy's git config by an `[include]` |

`defaults/agent` only records the choice. On a new machine still run
`omarchy default agent claude`, which also installs the agent through mise.

**Snapshots** — your file replaces the default outright. Tracked only where the
file is authoritative by design anyway:

- `config/omarchy/shell.json` — once you customize the bar, Omarchy stops
  merging its defaults back in (by design), so a tracked copy costs nothing.
- `config/omarchy/shell.toml` — small, entirely yours.

Everything else that's a plain copy of an upstream default is deliberately
**not** tracked: `starship.toml`, `btop.conf`, `lazygit/config.yml`,
`omarchy-menu.jsonc`, `omarchy/branding/`, and the terminal configs. Committing
those pins a stale version of a file Omarchy will keep improving.

That includes the hooks already sitting in `~/.config/omarchy/hooks/` —
`install-voxtype`, `setup-agent`, `setup-fingerprint` are Omarchy's own
first-run invitations, copied there by its installer. `hooks/*.d/` is still a
layered drop-in directory, so a hook you actually write belongs in the repo.

## Set by command, not tracked

These live in Omarchy's own state, so reproduce them by running the command
rather than restoring a file:

```sh
omarchy theme set catppuccin
omarchy font set "CaskaydiaMono Nerd Font"   # rewrites all four terminal configs
omarchy-toggle screensaver-off on            # idle goes straight to lock, no screensaver
omarchy default agent claude                 # installs via mise and writes defaults/agent
```

`omarchy theme set` now drives Neovim's colorscheme too: `config/nvim` reads
the staged spec at `~/.local/state/omarchy/current/theme/neovim.lua` and watches
that directory, so running open editors reskin without a restart. See the header
comment in `config/nvim/lua/config/theme.lua` for where it departs from
upstream's version, which assumes LazyVim and a symlinked config.

The screensaver toggle is a flag file at
`~/.local/state/omarchy/toggles/screensaver-off`. `off` restores it, and
Menu → Toggle → Screensaver flips it either way. It only suppresses the
screensaver — `idle.lock` in `shell.json` still locks on schedule.

Background: `3-blue-eye.png` (from the catppuccin theme).

Commit signing needs an untracked `~/.config/git/config.local` with
`user.signingkey` and `commit.gpgsign`; `config/git/personal` includes it.

Language toolchains come from `omarchy install dev-env <name>` (go, node,
python, ruby, dotnet). They're not tracked: the installer does more than drop a
binary -- ruby also gets rails and `~/.gemrc`, python also gets uv -- so a
copied `~/.config/mise/config.toml` would drift from it. `packages.sh` checks
for each one and prints the command to run when it's missing, rather than
installing it. Ruby is checked by whether it resolves inside mise, since
Omarchy's base install ships its own `/usr/bin/ruby`.

## Layout

| Path | Goes to |
|---|---|
| `config/hypr/` | `~/.config/hypr/` |
| `config/omarchy/` | `~/.config/omarchy/` |
| `config/nvim/` | `~/.config/nvim/` |
| `config/sesh/` | *(staged — see above)* |
| `config/git/personal` | *(applied by `[include]`, not a symlink)* |
| `home/.claude/` | *(staged)* |
| `home/.bashrc` | `~/.bashrc` |
| `packages.sh` | *(not linked — run to install packages)* |
| `other_configs/improvedtube.json` | *(not linked — import by hand, see below)* |

## Browser extension settings

`other_configs/improvedtube.json` is an [ImprovedTube](https://improvedtube.com/)
settings export (YouTube tweaks: no Shorts, no autoplay, 2x default speed,
subscriptions as the home page). Nothing symlinks it — `install.sh` only sweeps
`config/` and `home/`. Restore it by hand after installing the extension:
its options page → *Import/Export* → import this file. Re-export over it when
the settings change.

## History

The `main` branch holds the previous setup: `quill`, a Go CLI that managed
packages, modules, and profiles declaratively. Omarchy covers that ground, so
this branch starts fresh. `main` is kept as an archive — pull anything else
across with `git restore --source=main -- <path>`.
