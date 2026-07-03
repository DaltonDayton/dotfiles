# dotfiles

Arch Linux (and WSL/Ubuntu) machine setup managed by [`quill`](./cmd/quill), a Go CLI
that declaratively installs packages, links configs, enables services, and applies
host-specific tweaks via a Charm-powered TUI. Arch is the primary target; WSL/Ubuntu is
a supported target driven by the same os-gated modules (`profiles/wsl.toml`).

See `docs/superpowers/specs/2026-04-21-quill-design.md` for the design
and `docs/superpowers/plans/2026-04-21-quill-implementation.md` for the implementation plan.

## Bootstrap (fresh Arch or WSL/Ubuntu)

```sh
curl -fsSL https://raw.githubusercontent.com/DaltonDayton/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` detects the distro from `/etc/os-release` and installs prerequisites via
`pacman` (Arch) or `apt-get` (Ubuntu); anything else exits unsupported.

(Not yet published — see the plan for current status.)

## Modules

Most modules are self-describing via their `module.toml`. Two have hands-on usage notes:

- [`modules/hyprland/README.md`](./modules/hyprland/README.md) — theme/wallpaper keybinds, waybar layout switching.
- [`modules/windows-terminal/README.md`](./modules/windows-terminal/README.md) — cross-boundary settings merge, font install, backup/restore.
