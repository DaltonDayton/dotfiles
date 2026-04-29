#!/usr/bin/env bash
# Apply a theme: rewrite indirection files, set wallpaper, reload affected apps.
# Called by theme-switcher.sh and (indirectly) wallpaper-picker.sh.
#
# Usage: apply-theme.sh <theme-name>
set -euo pipefail

THEME="${1:-}"
[[ -z "$THEME" ]] && { echo "usage: $0 <theme-name>" >&2; exit 1; }

THEMES_DIR="$HOME/.config/themes"
THEME_DIR="$THEMES_DIR/$THEME"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
WALLPAPERS_STATE="$STATE_DIR/wallpapers.txt"
CURRENT_STATE="$STATE_DIR/current"

if [[ ! -d "$THEME_DIR" ]]; then
  notify-send "Theme error" "Unknown theme: $THEME" -u critical
  echo "unknown theme: $THEME" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"
touch "$WALLPAPERS_STATE"

# Persist active theme up front so any reload triggers (notably the matugen
# nvim post_hook firing during `matugen image`) read the new value.
echo "$THEME" > "$CURRENT_STATE"

# Detect mode (matugen or static) from meta.toml
mode="static"
if [[ -f "$THEME_DIR/meta.toml" ]] && grep -q '^mode = "matugen"' "$THEME_DIR/meta.toml"; then
  mode="matugen"
fi

# --- Build wallpaper pool -----------------------------------------------------
declare -a pool=()
if [[ "$mode" == "matugen" ]]; then
  # union of every theme's wallpapers/ + optional personal wallpaper dir
  matugen_extra_dir="${MATUGEN_WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers}"
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    {
      find -L "$THEMES_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0
      if [[ -d "$matugen_extra_dir" ]]; then
        find -L "$matugen_extra_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0
      fi
    } | sort -zu
  )
else
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    find "$THEME_DIR/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 2>/dev/null | sort -z
  )
fi

# --- Resolve wallpaper: last-used or first in pool ---------------------------
wallpaper=""
saved=""
saved_line=$(grep -m1 "^${THEME}:" "$WALLPAPERS_STATE" || true)
[[ -n "$saved_line" ]] && saved="${saved_line#*:}"
if [[ -n "$saved" && -f "$saved" ]]; then
  wallpaper="$saved"
elif (( ${#pool[@]} > 0 )); then
  wallpaper="${pool[0]}"
  # persist as default
  sed -i "/^${THEME}:/d" "$WALLPAPERS_STATE"
  printf '%s:%s\n' "$THEME" "$wallpaper" >> "$WALLPAPERS_STATE"
fi

# Track active wallpaper so hyprlock can render it at lock time.
[[ -n "$wallpaper" ]] && ln -sfn "$wallpaper" "$STATE_DIR/current_wallpaper"

# --- Rewrite indirection files ------------------------------------------------
write_one() {
  local file="$1" content="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$content" > "$file"
}

if [[ "$mode" == "matugen" ]]; then
  if [[ -n "$wallpaper" ]]; then
    matugen_input="$wallpaper"
    matugen_tmp=""
    ext="${wallpaper##*.}"
    mime=$(file --mime-type -b "$wallpaper" 2>/dev/null || true)
    if [[ "$mime" == "image/jpeg" && "$ext" != "jpg" && "$ext" != "jpeg" ]]; then
      matugen_tmp=$(mktemp --suffix=.jpg)
      cp "$wallpaper" "$matugen_tmp"
      matugen_input="$matugen_tmp"
    elif [[ "$mime" == "image/png" && "$ext" != "png" ]]; then
      matugen_tmp=$(mktemp --suffix=.png)
      cp "$wallpaper" "$matugen_tmp"
      matugen_input="$matugen_tmp"
    fi

    # matugen post-hooks regenerate matugen.* and reload each app
    if ! matugen image "$matugen_input" --prefer darkness; then
      [[ -n "$matugen_tmp" ]] && rm -f "$matugen_tmp"
      exit 1
    fi
    [[ -n "$matugen_tmp" ]] && rm -f "$matugen_tmp"
  fi

  write_one "$HOME/.config/hypr/colors/colors.conf"    'source = ~/.config/hypr/colors/matugen.conf'
  write_one "$HOME/.config/waybar/colors/colors.css"   '@import "matugen.css";'
  write_one "$HOME/.config/kitty/colors/colors.conf"   'include matugen.conf'
  write_one "$HOME/.config/rofi/colors/colors.rasi"    '@import "matugen.rasi"'
  write_one "$HOME/.config/swaync/colors/colors.css"   '@import "matugen.css";'
  write_one "$HOME/.config/wlogout/colors/colors.css"  '@import "matugen.css";'
  write_one "$HOME/.config/tmux/colors/colors.conf"    'source-file ~/.config/tmux/colors/matugen.conf'

  # Matugen post-hooks run before these indirection rewrites, so reload here too.
  hyprctl reload >/dev/null 2>&1 || true
  pkill -SIGUSR2 waybar 2>/dev/null || true
  if pids=$(pidof kitty 2>/dev/null) && [[ -n "$pids" ]]; then
    kill -SIGUSR1 $pids 2>/dev/null || true
  fi
  if pgrep -x swaync >/dev/null 2>&1; then
    pkill swaync 2>/dev/null || true
    (swaync >/dev/null 2>&1 &)
  fi
else
  write_one "$HOME/.config/hypr/colors/colors.conf"    "source = ~/.config/themes/${THEME}/hypr.conf"
  write_one "$HOME/.config/waybar/colors/colors.css"   "@import \"../../themes/${THEME}/waybar.css\";"
  write_one "$HOME/.config/kitty/colors/colors.conf"   "include ~/.config/themes/${THEME}/kitty.conf"
  write_one "$HOME/.config/rofi/colors/colors.rasi"    "@import \"../../themes/${THEME}/rofi.rasi\""
  write_one "$HOME/.config/swaync/colors/colors.css"   "@import \"../../themes/${THEME}/swaync.css\";"
  write_one "$HOME/.config/wlogout/colors/colors.css"  "@import \"../../themes/${THEME}/wlogout.css\";"
  write_one "$HOME/.config/tmux/colors/colors.conf"    "source-file ~/.config/themes/${THEME}/tmux.conf"

  # pywalfox reads from a fixed path and doesn't support indirection, so copy.
  if [[ -f "$THEME_DIR/pywalfox.json" ]]; then
    mkdir -p "$HOME/.cache/wal"
    cp "$THEME_DIR/pywalfox.json" "$HOME/.cache/wal/colors.json"
    pywalfox update >/dev/null 2>&1 || true
  fi

  if [[ -n "$wallpaper" ]]; then
    awww img "$wallpaper" \
      --transition-type center --transition-fps 165 \
      --transition-step 30 --transition-duration 2 \
      >/dev/null 2>&1 || true
  fi
  hyprctl reload >/dev/null 2>&1 || true
  pkill -SIGUSR2 waybar 2>/dev/null || true
  if pids=$(pidof kitty 2>/dev/null) && [[ -n "$pids" ]]; then
    kill -SIGUSR1 $pids 2>/dev/null || true
  fi
  if pgrep -x swaync >/dev/null 2>&1; then
    pkill swaync 2>/dev/null || true
    (swaync >/dev/null 2>&1 &)
  fi
  pkill -SIGUSR1 nvim 2>/dev/null || true
fi

tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1 || true

notify-send "Theme" "$THEME" || true
