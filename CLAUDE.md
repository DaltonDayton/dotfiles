# dotfiles (Omarchy)

Override files for an [Omarchy](https://omarchy.org/) system, symlinked into
place by `./install.sh`. See `README.md` for the layout.

Omarchy ships a Claude skill at `~/.claude/skills/omarchy/` — use it for any
question about *what* to put in these configs (Hyprland bindings, bar widgets,
themes, hooks, `omarchy` commands). This file only covers the repo itself.

## Working here

- Files under `config/` and `home/` are symlinked to `~/.config/` and `~/`.
  Editing the repo copy edits the live config, and vice versa — no build step.
- After adding a file, run `./install.sh` to link it. `--dry` previews.
- Never edit `/usr/share/omarchy/` — it's package-owned and `omarchy update`
  overwrites it. Reading it to see the defaults is fine and encouraged.
- Validate Hyprland changes with `hyprctl reload && hyprctl configerrors`.
  `shell.json` and `omarchy-menu.jsonc` hot-reload on save.

## Before tracking a new file, check how it layers

Omarchy uses both models, and the difference decides whether the file belongs
in git at all:

- **Layered** (`~/.config/hypr/*.lua`, `hooks/*.d/`, `themed/*.tpl`,
  `themes/<name>/`, `extensions/omarchy-menu.jsonc`) — upstream keeps its
  defaults, your file only adds or overrides. Safe to track.
- **Snapshot** (`shell.json`, terminal configs, `git/config`, `btop.conf`,
  `starship.toml`) — Omarchy copies its default to `~/.config` at install and
  never merges again. Tracking one of these pins a stale copy of a file
  upstream will keep improving.

So: `diff /usr/share/omarchy/config/<path> ~/.config/<path>` first. If it's
identical to the default, don't track it. If it's a snapshot you've genuinely
customized, track it and accept that it's frozen — or find the layered
equivalent (a `themed/` template, a hook, an `[include]`) and use that instead.

Settings that have a first-class command (`omarchy theme set`,
`omarchy font set`) belong in README's "Set by command" section, not in a
tracked file.

## Not in scope

`main` is the archived pre-Omarchy setup (the `quill` Go CLI). Don't port its
patterns here — this branch is deliberately a plain symlink repo.
