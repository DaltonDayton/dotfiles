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
- runs its `off` (removes added lines, resets bar settings, stops what it started)
- removes its links, restoring the Omarchy file each one replaced
- removes the packages install.sh installed for it (`omarchy pkg drop`), keeping
  any that were already there or that another enabled feature lists

It leaves empty directories and `.drift` files behind.

## Features

`features/<name>/` can hold any of:

| File | Effect |
|---|---|
| `about` | one line, shown in the picker |
| `hypr.lua` | linked to `~/.config/hypr/features/<name>.lua`, which Omarchy's `hyprland.lua` loads (install.sh appends one line for it) |
| `files/…` | mirrors `~`, and each file is symlinked there. Any real file in the way is moved to `.bak.<epoch>` |
| `linkdirs` | paths under `files/` to link as one directory (e.g. nvim, which lazy.nvim writes into) |
| `packages`, `aur` | installed with `omarchy pkg add` / `omarchy pkg aur add` |
| `setup`, `off` | bash sourced by install.sh with helpers (`run`, `ensure_line`, `bar_set`, …); must be safe to rerun |
| `upstream` | snapshots of Omarchy files: `<path under files/>` TAB `<path under /usr/share/omarchy/>`, one per line, for `omarchy-diff` |

Omarchy's `bindings.lua`, `input.lua`, `looknfeel.lua`, `autostart.lua`,
`.bashrc`, git config, and `shell.json` stay Omarchy's. Features add to them
through a hypr feature file, a `source`/`[include]` line, or `omarchy bar set`.

If Omarchy rewrites a linked file in place (its monitor scaling does this to
`monitors.lua`), the next install keeps the rewritten copy as `.drift.<epoch>`
and prints the `diff` command so you can pull the change in.

## Keeping up with Omarchy

Some features ship a snapshot of an Omarchy file instead of layering on it
(`starship.toml`, `hyprsunset.conf`, `monitors.lua`, the cloned workspaces
widget). Each one is declared in the feature's `upstream` file, and Omarchy's
version as of the last sync lives under `upstream/`, mirroring
`/usr/share/omarchy/`. After `omarchy update`, the `basics` feature sends a
notification if any of them changed, and every new shell repeats the reminder
until they are back in sync:

```sh
./omarchy-diff                 # what Omarchy changed since the last sync
./omarchy-diff --merge         # per file: merge (3-way, review with git diff), keep mine, or later
./omarchy-diff --merge --all   # merge everything without asking
```

A snapshot without a baseline gets one recorded on the next run.

## By hand

- **Git signing:** `~/.config/git/config.local` with `user.signingkey` and `commit.gpgsign`.
- **Dictation:** `omarchy voxtype install`, then `sudo voxtype setup gpu --enable` (Omarchy's install
  tries this but ignores a failure) and `omarchy voxtype model` -> `large-v3-turbo`. The desktop's
  `yt-transcript` uses that same model.
- **Bar plugins** (third-party, run unsandboxed, so review before installing):
  `omarchy plugin add https://github.com/rmacy/omarchy-system-monitor.git` (CPU/temp chip; pick
  monitors in its settings). Not hyprmoncfg: applying a layout from it writes its own workspace
  rules and a loader into `hyprland.lua` that override `monitors.lua`. Edit the feature file instead.
- **Tray pins** (desktop): pin Steam, Discord, NordVPN from the tray itself.
- **Battle.net:** `omarchy install gaming battlenet` before enabling `battlenet-tsm`.
- **Unreal Engine, Blender** (desktop): manual installs under `~/software/`. The `unreal` feature
  ships the window rules and `nvim-ue`; `features/unreal/README.md` is the runbook (engine,
  accessor plugin build, Fab, Blender, Starter Content).
- **ImprovedTube:** import `other_configs/improvedtube.json` from the extension's options page.
- **Claude Code ECC plugin:** `/plugin marketplace add affaan-m/ecc`, then `/plugin install ecc@ecc`.
- **herdr's Claude hook** is tracked in the `claude` feature, so don't run `herdr integration
  install claude`: it appends a duplicate absolute-path hook entry to `settings.json`. After a herdr
  update, copy its new script over the tracked one if `herdr integration status` says outdated.

The pre-Omarchy setup is archived on the `quill` branch.
