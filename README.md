# dotfiles

My overrides on top of [Omarchy](https://omarchy.org/). Omarchy keeps its
defaults in `/usr/share/omarchy/`; this repo holds only what I changed, split
into small features that each machine's profile picks from.

## Install

```sh
git clone git@github.com:DaltonDayton/dotfiles.git ~/dotfiles
~/dotfiles/install.sh             # first run asks for a profile
~/dotfiles/install.sh --pick      # choose the profile's features from a checklist
```

`install.sh` applies `profiles/<profile>`, one feature name per line. For each
feature it installs missing packages, links its files, and runs its setup.
Rerunning changes nothing unless the list or a feature changed. Every change is
also logged to `~/.local/state/dotfiles/install.log`.

Dropping a feature from the list undoes it on the next run:
- runs its `off` (removes added lines, resets bar settings, disables plugins, stops what it started)
- removes its links, restoring the Omarchy file each one replaced
- removes the packages install.sh installed for it (`omarchy pkg drop`), keeping
  any that were already there or that another enabled feature lists

It leaves plugin clones, empty directories, and `.drift` files behind.

## Features

`features/<name>/` can hold any of:

| File | Effect |
|---|---|
| `about` | one line, shown in the picker |
| `hypr.lua` | linked to `~/.config/hypr/features/<name>.lua`, which Omarchy's `hyprland.lua` loads (install.sh appends one line for it) |
| `files/…` | mirrors `~`, and each file is symlinked there. Any real file in the way is moved to `.bak.<epoch>` |
| `linkdirs` | paths under `files/` to link as one directory (e.g. nvim, which lazy.nvim writes into) |
| `packages`, `aur` | installed with `omarchy pkg add` / `omarchy pkg aur add` |
| `setup`, `off` | bash sourced by install.sh with helpers (`run`, `ensure_line`, `bar_set`, `bar_put`, `plugin_add`, …); must be safe to rerun |

Omarchy's `bindings.lua`, `input.lua`, `looknfeel.lua`, `autostart.lua`,
`.bashrc`, git config, and `shell.json` stay Omarchy's. Features add to them
through a hypr feature file, a `source`/`[include]` line, or `omarchy bar set`.

If Omarchy rewrites a linked file in place (its monitor scaling does this to
`monitors.lua`), the next install keeps the rewritten copy as `.drift.<epoch>`
and prints the `diff` command so you can pull the change in.

## Keeping up with Omarchy

A few features ship a snapshot of an Omarchy file (`starship.toml`,
`hyprsunset.conf`). Omarchy's version as of the last sync lives in `upstream/`.
After `omarchy update` (the `omarchy-diff-hook` feature sends a notification):

```sh
./omarchy-diff           # what Omarchy changed since the last sync
./omarchy-diff --merge   # 3-way merge it into the feature copies, then review with git diff
```

## By hand

- **Git signing:** `~/.config/git/config.local` with `user.signingkey` and `commit.gpgsign`.
- **Dev toolchains** (nvim's mason tools need them): `omarchy install dev-env <go|node|python|ruby|dotnet>`.
- **Battle.net:** `omarchy install gaming battlenet` before enabling `battlenet-tsm`.
- **ImprovedTube:** import `other_configs/improvedtube.json` from the extension's options page.
- **Claude Code ECC plugin:** `/plugin marketplace add affaan-m/ecc`, then `/plugin install ecc@ecc`.

The pre-Omarchy setup is archived on `main`.
