# hyprland module

Hyprland WM config, bar, terminal, and theming engine. Shipped as the `hyprland`
quill module; symlinked into `~/.config/` on `apply`.

## Theme switching

Built in via keybinds:

- `Super+D` opens the theme picker.
- `Super+Shift+D` opens the wallpaper picker.

Theme bundles live in `files/themes/` (static bundles + `matugen`).

## Waybar layout selection

Waybar is symlinked as a directory (`~/.config/waybar`); the active layout is selected
by two internal symlinks quill does *not* manage:

- `~/.config/waybar/config.jsonc` -> `layouts/<layout>/config.jsonc`
- `~/.config/waybar/style.css` -> `layouts/<layout>/style.css`

Switch layouts manually by changing those symlinks, then restarting waybar:

```sh
ln -sfn layouts/velvetline/config.jsonc ~/.config/waybar/config.jsonc
ln -sfn layouts/velvetline/style.css ~/.config/waybar/style.css
~/.config/waybar/scripts/launch.sh
```
