#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Matugen first-run render --------------------------------------
# Skip if colors already exist — runtime theme swaps go through a separate
# user-bound script that calls matugen directly. Quill never re-renders.
if [[ ! -f "$HOME/.config/hypr/colors/matugen.conf" ]]; then
  matugen image "$MODULE_DIR/files/wallpapers/default.png"
fi

# --- Theme indirection first-run seed ------------------------------
# Indirection files are mutable (rewritten by apply-theme.sh on every
# theme switch). Quill can't manage them as [[symlinks]] or [[files]] —
# this seeds them with rose-pine on first install and never touches
# them again.
seed_indirection() {
  local target="$1" content="$2"
  if [[ ! -f "$target" ]]; then
    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$content" > "$target"
  fi
}

seed_indirection "$HOME/.config/hypr/colors/colors.conf"    'source = ~/.config/themes/rose-pine/hypr.conf'
seed_indirection "$HOME/.config/waybar/colors/colors.css"   '@import "../../themes/rose-pine/waybar.css";'
seed_indirection "$HOME/.config/kitty/colors/colors.conf"   'include ~/.config/themes/rose-pine/kitty.conf'
seed_indirection "$HOME/.config/rofi/colors/colors.rasi"    '@import "../../themes/rose-pine/rofi.rasi";'
seed_indirection "$HOME/.config/swaync/colors/colors.css"   '@import "../../themes/rose-pine/swaync.css";'
seed_indirection "$HOME/.config/wlogout/colors/colors.css"  '@import "../../themes/rose-pine/wlogout.css";'

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
mkdir -p "$STATE_DIR"
[[ -f "$STATE_DIR/current" ]] || echo rose-pine > "$STATE_DIR/current"
