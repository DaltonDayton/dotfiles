# dotfiles (wsl)

Terminal-only setup for Ubuntu 24.04 under WSL. It started as a snapshot of
the Omarchy configs from my personal machines (branch `slim`) and forks from
there; nothing here tracks Omarchy. Split into small features that a profile
picks from.

## Install

```sh
git clone -b wsl git@github.com:DaltonDayton/dotfiles.git ~/dotfiles
~/dotfiles/install.sh --profile wsl
~/dotfiles/install.sh --pick      # choose the profile's features from a checklist
```

`install.sh` applies `profiles/<profile>`, one feature name per line. For each
feature it installs missing apt packages and mise tools, links its files, and
runs its setup. It installs mise itself on the first run. Rerunning changes
nothing unless the list or a feature changed. Every change is also logged to
`~/.local/state/dotfiles/install.log`.

Dropping a feature from the list undoes it on the next run:
- runs its `off` (removes added lines, stops what it started)
- removes its links, restoring the file each one replaced
- removes the packages and tools install.sh installed for it, keeping any that
  were already there or that another enabled feature lists

It leaves empty directories and `.drift` files behind.

## Features

`features/<name>/` can hold any of:

| File | Effect |
|---|---|
| `about` | one line, shown in the picker |
| `files/…` | mirrors `~`, and each file is symlinked there. Any real file in the way is moved to `.bak.<epoch>` |
| `linkdirs` | paths under `files/` to link as one directory (e.g. nvim, which lazy.nvim writes into) |
| `packages` | apt packages |
| `mise` | tools installed with `mise use --global <tool>@latest` |
| `setup`, `off` | bash sourced by install.sh with helpers (`run`, `say`, `ensure_line`, …); must be safe to rerun |

The `basics` feature carries the Omarchy shell: `bash/` is Omarchy's
`default/bash/` (envs, aliases, functions, init, inputrc) with the Ubuntu and
no-desktop edits applied, `bash/personal` is my own additions, and
`files/.config/` holds the git, tmux, herdr, and starship configs. `bat` and
`fd` get `~/.local/bin` symlinks to Ubuntu's renamed binaries.

## By hand

- **Git identity:** `~/.config/git/config.local` with `[user] name`/`email`,
  plus `user.signingkey` and `commit.gpgsign` if signing.
- **Nvim theme:** `features/nvim/files/.local/state/omarchy/current/theme/neovim.lua`
  is the Omarchy theme spec nvim reads (catppuccin). Swap it for another theme's
  `neovim.lua` from Omarchy's `themes/<name>/` to change colorscheme.
- **Claude Code ECC plugin:** `/plugin marketplace add affaan-m/ecc`, then `/plugin install ecc@ecc`.
