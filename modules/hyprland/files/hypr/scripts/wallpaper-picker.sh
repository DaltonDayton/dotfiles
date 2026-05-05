#!/usr/bin/env bash
# Rofi wallpaper picker. In matugen mode, pool = union of every theme's
# wallpapers/ and selection triggers `matugen image`. In static mode,
# pool = current theme only and selection just changes the wallpaper.
# By default `local/` subdirs are excluded; press Alt+L inside the picker
# to re-launch with WALLPAPER_PICKER_INCLUDE_LOCAL=1 and reveal them.
# Bound to Super+Shift+D.
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
WALLPAPERS_STATE="$STATE_DIR/wallpapers.txt"
CURRENT_STATE="$STATE_DIR/current"
ROFI_THEME="$HOME/.config/rofi/wallpaper-picker.rasi"
ROFI_THUMBNAIL_PROFILE="r280x158-v1"
ROFI_THUMBNAIL_CMD="$HOME/.config/hypr/scripts/rofi-thumbnail.sh \"{input}\" \"{output}\" \"{size}\" 280 158"
rofi_theme_args=()
if [[ -f "$ROFI_THEME" ]]; then
  rofi_theme_args=(-theme "$ROFI_THEME")
fi

INCLUDE_LOCAL="${WALLPAPER_PICKER_INCLUDE_LOCAL:-}"
find_filter=()
[[ -z "$INCLUDE_LOCAL" ]] && find_filter=(! -path '*/local/*')

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
  # Dedupe by content hash: a wallpaper claimed by multiple static themes
  # exists as physical copies in each theme's wallpapers/ dir; in matugen
  # mode the union pool would otherwise show it once per theme.
  declare -A seen_hashes=()
  while IFS= read -r -d '' f; do
    hash=$(sha256sum "$f" | cut -d' ' -f1)
    if [[ -z "${seen_hashes[$hash]:-}" ]]; then
      seen_hashes[$hash]=1
      pool+=("$f")
    fi
  done < <(
    {
      find -L "$THEMES_DIR" -type f "${find_filter[@]}" \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0
      if [[ -d "$matugen_extra_dir" ]]; then
        find -L "$matugen_extra_dir" -type f "${find_filter[@]}" \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0
      fi
    } | sort -zu
  )
else
  while IFS= read -r -d '' f; do pool+=("$f"); done < <(
    find "$THEME_DIR/wallpapers" -type f "${find_filter[@]}" \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 2>/dev/null | sort -z
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
# Alt+L exits with status 10 (custom-1) so we can re-launch with local included.
prompt="Wallpaper (PgDn/PgUp)"
[[ -z "$INCLUDE_LOCAL" ]] && prompt="Wallpaper (Alt+L: local)"
status=0
selected_idx=$(
  {
    for i in "${!pool[@]}"; do
      wp="${pool[$i]}"
      label="$(basename "$wp")"

      if [[ "$wp" == "$current_wp" ]]; then
        label="● $label"
      fi
      printf '%s\0icon\x1fthumbnail://%s?%s\n' "$label" "$wp" "$ROFI_THUMBNAIL_PROFILE"
    done
  } | rofi -no-config -dmenu -i -show-icons -format i -p "$prompt" \
      -kb-custom-1 'Alt+l' \
      -preview-cmd "$ROFI_THUMBNAIL_CMD" \
      "${rofi_theme_args[@]}"
) || status=$?

if (( status == 10 )); then
  exec env WALLPAPER_PICKER_INCLUDE_LOCAL=1 "$0"
fi
[[ -z "$selected_idx" ]] && exit 0
selected_path="${pool[$selected_idx]:-}"
[[ -z "$selected_path" ]] && { notify-send "Wallpaper" "Could not resolve selection index: $selected_idx" -u critical; exit 1; }

# Persist
sed -i "/^${THEME}:/d" "$WALLPAPERS_STATE"
printf '%s:%s\n' "$THEME" "$selected_path" >> "$WALLPAPERS_STATE"
ln -sfn "$selected_path" "$STATE_DIR/current_wallpaper"

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
