# dotfiles

Arch Linux machine setup managed by [`quill`](./cmd/quill), a Go CLI that declaratively
installs packages, links configs, enables services, and applies host-specific tweaks
via a Charm-powered TUI.

See `docs/superpowers/specs/2026-04-21-quill-design.md` for the design
and `docs/superpowers/plans/2026-04-21-quill-implementation.md` for the implementation plan.

## Bootstrap (on a fresh Arch install)

```sh
curl -fsSL https://raw.githubusercontent.com/DaltonDayton/dotfiles/main/bootstrap.sh | bash
```

(Not yet published — see the plan for current status.)

### Bootstrap from the `startover` branch (current WIP)

```sh
DOTFILES_BRANCH=startover bash <(curl -fsSL https://raw.githubusercontent.com/DaltonDayton/dotfiles/startover/bootstrap.sh)
```

## Hyprland Notes

- Hyprland config ships as the `hyprland` quill module under `modules/hyprland/`.
- Theme switching is built in:
  - `Super+D` opens the theme picker.
  - `Super+Shift+D` opens the wallpaper picker.
- Theme bundles live in `modules/hyprland/files/themes/` (static bundles + `matugen`).

## Waybar Layout Selection

Waybar is symlinked as a directory (`~/.config/waybar`), and the active layout is selected by two internal symlinks:

- `~/.config/waybar/config.jsonc` -> `layouts/<layout>/config.jsonc`
- `~/.config/waybar/style.css` -> `layouts/<layout>/style.css`

Switch layouts manually by changing those symlinks, then restarting waybar:

```sh
ln -sfn layouts/velvetline/config.jsonc ~/.config/waybar/config.jsonc
ln -sfn layouts/velvetline/style.css ~/.config/waybar/style.css
~/.config/waybar/scripts/launch.sh
```
