#!/usr/bin/env bash
# Rofi wallpaper picker. In matugen mode, pool = union of every theme's
# wallpapers/ and selection triggers `matugen image`. In static mode,
# pool = current theme only and selection just changes the wallpaper.
# Bound to Super+Shift+D.
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
WALLPAPERS_STATE="$STATE_DIR/wallpapers.txt"
CURRENT_STATE="$STATE_DIR/current"

if [[ ! -f "$CURRENT_STATE" ]]; then
  notify-send "Wallpaper" "No active theme — run Super+D first" -u critical
  exit 1
fi
THEME=$(cat "$CURRENT_STATE")
THEME_DIR="$THEMES_DIR/$THEME"

# Detect matugen mode
mode="static"
if [[ -f "$THEME_DIR/meta.toml" ]] && grep -q '^mode = "matugen"' "$THEME_DIR/meta.toml"; then
  mode="matugen"
fi

# Build pool
declare -a pool=()
if [[ "$mode" == "matugen" ]]; then
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

if (( ${#pool[@]} == 0 )); then
  notify-send "Wallpaper" "No wallpapers found for theme: $THEME" -u critical
  exit 1
fi

mkdir -p "$STATE_DIR"
touch "$WALLPAPERS_STATE"
current_wp=$(grep "^${THEME}:" "$WALLPAPERS_STATE" | head -n1 | cut -d':' -f2-)

# Build rofi rows using -format i so selection resolves by index. This avoids
# relying on NUL bytes in shell variables (bash strings cannot hold them).
selected_idx=$(
  {
    for i in "${!pool[@]}"; do
      wp="${pool[$i]}"
      if [[ "$mode" == "matugen" ]]; then
        theme_part=$(basename "$(dirname "$(dirname "$wp")")")
        label="$theme_part/$(basename "$wp")"
      else
        label="$(basename "$wp")"
      fi

      if [[ "$wp" == "$current_wp" ]]; then
        label="● $label"
      fi
      printf '%s\0icon\x1f%s\n' "$label" "$wp"
    done
  } | rofi -dmenu -i -show-icons -format i -p "Wallpaper"
)

[[ -z "$selected_idx" ]] && exit 0
selected_path="${pool[$selected_idx]:-}"
[[ -z "$selected_path" ]] && { notify-send "Wallpaper" "Could not resolve selection index: $selected_idx" -u critical; exit 1; }

# Persist
sed -i "/^${THEME}:/d" "$WALLPAPERS_STATE"
printf '%s:%s\n' "$THEME" "$selected_path" >> "$WALLPAPERS_STATE"

# Apply
if [[ "$mode" == "matugen" ]]; then
  matugen_input="$selected_path"
  matugen_tmp=""
  ext="${selected_path##*.}"
  mime=$(file --mime-type -b "$selected_path" 2>/dev/null || true)
  if [[ "$mime" == "image/jpeg" && "$ext" != "jpg" && "$ext" != "jpeg" ]]; then
    matugen_tmp=$(mktemp --suffix=.jpg)
    cp "$selected_path" "$matugen_tmp"
    matugen_input="$matugen_tmp"
  elif [[ "$mime" == "image/png" && "$ext" != "png" ]]; then
    matugen_tmp=$(mktemp --suffix=.png)
    cp "$selected_path" "$matugen_tmp"
    matugen_input="$matugen_tmp"
  fi

  if ! matugen image "$matugen_input" --prefer darkness; then
    [[ -n "$matugen_tmp" ]] && rm -f "$matugen_tmp"
    notify-send "Wallpaper" "Matugen failed for $(basename "$selected_path")" -u critical
    exit 1
  fi
  [[ -n "$matugen_tmp" ]] && rm -f "$matugen_tmp"
else
  awww img "$selected_path" \
    --transition-type wipe --transition-fps 165 \
    --transition-step 30 --transition-duration 2 \
    >/dev/null 2>&1 || true
fi

notify-send "Wallpaper" "$(basename "$selected_path")"
