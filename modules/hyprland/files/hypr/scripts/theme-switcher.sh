#!/usr/bin/env bash
# Rofi theme picker: thumbnail grid of themes; tile icon is the theme's
# most recently selected wallpaper (from wallpapers.txt), falling back to
# the alphabetically-first wallpaper in the theme's wallpapers/ dir.
# Bound to Super+D.
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
WALLPAPERS_STATE="$STATE_DIR/wallpapers.txt"
APPLY="$HOME/.config/hypr/scripts/apply-theme.sh"
ROFI_THEME="$HOME/.config/rofi/wallpaper-picker.rasi"
ROFI_THUMBNAIL_PROFILE="r280x158-v1"
ROFI_THUMBNAIL_CMD="$HOME/.config/hypr/scripts/rofi-thumbnail.sh \"{input}\" \"{output}\" \"{size}\" 280 158"
rofi_theme_args=()
[[ -f "$ROFI_THEME" ]] && rofi_theme_args=(-theme "$ROFI_THEME")

current=""
[[ -f "$STATE_DIR/current" ]] && current=$(cat "$STATE_DIR/current")

mapfile -t dirs < <(find -L "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' | sort)

declare -a labels=() icons=() theme_names=()
for d in "${dirs[@]}"; do
  label="$d"
  if [[ -f "$THEMES_DIR/$d/meta.toml" ]]; then
    dn=$(grep -E '^display_name' "$THEMES_DIR/$d/meta.toml" | head -n1 | cut -d'"' -f2 || true)
    [[ -n "$dn" ]] && label="$dn"
  fi
  [[ "$d" == "$current" ]] && label="● $label"

  icon=""
  if [[ -f "$WALLPAPERS_STATE" ]]; then
    last=$(grep "^${d}:" "$WALLPAPERS_STATE" | head -n1 | cut -d':' -f2-)
    [[ -n "$last" && -f "$last" ]] && icon="$last"
  fi
  if [[ -z "$icon" ]]; then
    icon=$(find -L "$THEMES_DIR/$d/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort | head -n1)
  fi

  labels+=("$label")
  icons+=("$icon")
  theme_names+=("$d")
done

selected_idx=$(
  {
    for i in "${!labels[@]}"; do
      if [[ -n "${icons[$i]}" ]]; then
        printf '%s\0icon\x1fthumbnail://%s?%s\n' "${labels[$i]}" "${icons[$i]}" "$ROFI_THUMBNAIL_PROFILE"
      else
        printf '%s\n' "${labels[$i]}"
      fi
    done
  } | rofi -no-config -dmenu -i -show-icons -format i -p "Theme (PgDn/PgUp)" \
      -preview-cmd "$ROFI_THUMBNAIL_CMD" \
      "${rofi_theme_args[@]}"
)

[[ -z "$selected_idx" ]] && exit 0
theme="${theme_names[$selected_idx]:-}"
[[ -z "$theme" ]] && { notify-send "Theme" "Could not resolve selection index: $selected_idx" -u critical; exit 1; }

exec "$APPLY" "$theme"
