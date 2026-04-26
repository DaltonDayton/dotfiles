#!/usr/bin/env bash
# Rofi theme picker: list theme bundles, mark current, apply on selection.
# Bound to Super+D.
set -euo pipefail

THEMES_DIR="$HOME/.config/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/themes"
APPLY="$HOME/.config/hypr/scripts/apply-theme.sh"

current=""
[[ -f "$STATE_DIR/current" ]] && current=$(cat "$STATE_DIR/current")

# Build labeled list: optional display_name from meta.toml, fall back to dir name
declare -A label_to_dir=()
mapfile -t dirs < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' | sort)

menu=""
for d in "${dirs[@]}"; do
  label="$d"
  if [[ -f "$THEMES_DIR/$d/meta.toml" ]]; then
    dn=$(grep -E '^display_name' "$THEMES_DIR/$d/meta.toml" | head -n1 | cut -d'"' -f2 || true)
    [[ -n "$dn" ]] && label="$dn"
  fi
  label_to_dir["$label"]="$d"
  if [[ "$d" == "$current" ]]; then
    menu+="● $label"$'\n'
  else
    menu+="  $label"$'\n'
  fi
done

selected=$(printf '%s' "$menu" | rofi -dmenu -i -p "Theme")
[[ -z "$selected" ]] && exit 0

# Strip the prefix marker
selected="${selected#● }"
selected="${selected#  }"

theme="${label_to_dir[$selected]:-}"
[[ -z "$theme" ]] && { notify-send "Theme" "Unknown selection: $selected" -u critical; exit 1; }

exec "$APPLY" "$theme"
