#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Device-keyed internal symlinks --------------------------------
# Pick the variant whose filename matches $HOSTNAME, falling back to default.
# The link target is relative so it stays valid through the parent
# files/hypr -> ~/.config/hypr symlink.
link_device_variant() {
  local dir="$1" target_link="$2" fallback="$3"
  local pick="$dir/${HOSTNAME}.conf"
  [[ -f "$pick" ]] || pick="$dir/${fallback}.conf"
  ln -sfn "$(basename "$(dirname "$pick")")/$(basename "$pick")" "$target_link"
}

link_device_variant "$MODULE_DIR/files/hypr/monitors" "$MODULE_DIR/files/hypr/monitors.conf" "default"
link_device_variant "$MODULE_DIR/files/voxtype/configs" "$MODULE_DIR/files/voxtype/config.toml" "default"

# --- SDDM (sudo) ---------------------------------------------------
# /etc/sddm.conf is a sudo symlink so live edits to the tracked file apply
# without re-copying. The theme bundle is sudo-cp'd because /usr/share/ is
# root-owned and SDDM reads it directly. theme.${HOSTNAME}.conf, if present,
# overrides the default theme.conf for that host (e.g. larger font on laptop).
if [[ "$(readlink /etc/sddm.conf 2>/dev/null)" != "$MODULE_DIR/files/sddm.conf" ]]; then
  sudo ln -sfn "$MODULE_DIR/files/sddm.conf" /etc/sddm.conf
fi

SDDM_THEME_DIR="/usr/share/sddm/themes/quill"
if ! sudo diff -rq "$MODULE_DIR/files/sddm-theme" "$SDDM_THEME_DIR" >/dev/null 2>&1; then
  sudo mkdir -p "$SDDM_THEME_DIR"
  sudo cp -rT "$MODULE_DIR/files/sddm-theme" "$SDDM_THEME_DIR"
fi

HOST_THEME="$MODULE_DIR/files/sddm-theme/theme.${HOSTNAME}.conf"
if [[ -f "$HOST_THEME" ]]; then
  sudo cp "$HOST_THEME" "$SDDM_THEME_DIR/theme.conf"
fi

# --- Xorg drop-in (sudo, host-keyed) -------------------------------
# SDDM greeter is X11; on Optimus laptops we restrict X to the Intel iGPU
# to avoid the NVIDIA dirty-state segfault on warm reboot. Host-keyed: only
# applies if files/xorg/${HOSTNAME}.conf exists.
XORG_SRC="$MODULE_DIR/files/xorg/${HOSTNAME}.conf"
XORG_DROPIN="/etc/X11/xorg.conf.d/20-nvidia-ignore.conf"
if [[ -f "$XORG_SRC" ]]; then
  if [[ "$(readlink "$XORG_DROPIN" 2>/dev/null)" != "$XORG_SRC" ]]; then
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo ln -sfn "$XORG_SRC" "$XORG_DROPIN"
  fi
fi

# --- Voxtype first-run setup ---------------------------------------
# Idempotent: --download skips a cached model; gpu --enable is a no-op when
# already enabled; systemd is guarded by file existence. We deliberately
# don't run `voxtype setup compositor hyprland` — files/hypr/conf.d/
# voxtype-submap.conf is tracked in the repo and sourced from hyprland.conf.
if command -v voxtype >/dev/null 2>&1; then
  voxtype setup --download
  sudo voxtype setup gpu --enable
  [[ -f "$HOME/.config/systemd/user/voxtype.service" ]] || voxtype setup systemd
fi

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
seed_indirection "$HOME/.config/rofi/colors/colors.rasi"    '@import "../../themes/rose-pine/rofi.rasi"'
seed_indirection "$HOME/.config/swaync/colors/colors.css"   '@import "../../themes/rose-pine/swaync.css";'
seed_indirection "$HOME/.config/wlogout/colors/colors.css"  '@import "../../themes/rose-pine/wlogout.css";'
seed_indirection "$HOME/.config/tmux/colors/colors.conf"    'source-file ~/.config/themes/rose-pine/tmux.conf'

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
mkdir -p "$STATE_DIR"
[[ -f "$STATE_DIR/current" ]] || echo rose-pine > "$STATE_DIR/current"
[[ -L "$STATE_DIR/current_wallpaper" ]] || ln -sfn "$MODULE_DIR/files/wallpapers/default.png" "$STATE_DIR/current_wallpaper"
