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
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    find "$THEMES_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 | sort -z
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

# Build rofi menu + label->path map. In matugen mode the pool unions
# multiple theme dirs, so prefix the label with the theme name to avoid
# basename collisions (two themes can both ship a `default.png`).
declare -A label_to_path=()
menu=""
for wp in "${pool[@]}"; do
  if [[ "$mode" == "matugen" ]]; then
    theme_part=$(basename "$(dirname "$(dirname "$wp")")")
    label="$theme_part/$(basename "$wp")"
  else
    label="$(basename "$wp")"
  fi
  label_to_path["$label"]="$wp"
  if [[ "$wp" == "$current_wp" ]]; then
    menu+="● ${label}"$'\0'"icon"$'\x1f'"${wp}"$'\n'
  else
    menu+="${label}"$'\0'"icon"$'\x1f'"${wp}"$'\n'
  fi
done

selected=$(printf '%s' "$menu" | rofi -dmenu -i -show-icons -p "Wallpaper")
[[ -z "$selected" ]] && exit 0
selected="${selected#● }"

selected_path="${label_to_path[$selected]:-}"
[[ -z "$selected_path" ]] && { notify-send "Wallpaper" "Could not resolve: $selected" -u critical; exit 1; }

# Persist
sed -i "/^${THEME}:/d" "$WALLPAPERS_STATE"
printf '%s:%s\n' "$THEME" "$selected_path" >> "$WALLPAPERS_STATE"

# Apply
if [[ "$mode" == "matugen" ]]; then
  matugen image "$selected_path"
else
  awww img "$selected_path" \
    --transition-type wipe --transition-fps 165 \
    --transition-step 30 --transition-duration 2 \
    >/dev/null 2>&1 || true
fi

notify-send "Wallpaper" "$(basename "$selected_path")"
