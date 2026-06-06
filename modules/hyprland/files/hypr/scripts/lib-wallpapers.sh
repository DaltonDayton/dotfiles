#!/usr/bin/env bash
# Manifest-driven wallpaper lookup. Sourced by theme-switcher.sh,
# wallpaper-picker.sh, and apply-theme.sh — not executed directly.
#
# Layout: $WALLPAPERS_DIR/{manifest,*.jpg|png, local/{manifest,*.jpg|png}}
# Manifest line: "<filename>: <theme> [<theme> ...]"; '#' comments allowed.
# A file on disk with no manifest line is matugen-only by design.
# WALLPAPERS_DIR is overridable for tests.

WALLPAPERS_DIR="${WALLPAPERS_DIR:-$HOME/.config/wallpapers}"

# wallpapers_for_theme <theme> [include_local]
# Emits absolute paths assigned to <theme>, manifest order, tracked manifest
# first. Lines whose file is missing are skipped (tolerates deletions and
# local/ files absent on other machines).
wallpapers_for_theme() {
  local theme="$1" include_local="${2:-}"
  local manifests=("$WALLPAPERS_DIR/manifest")
  [[ -n "$include_local" ]] && manifests+=("$WALLPAPERS_DIR/local/manifest")
  local m dir line fname themes
  for m in "${manifests[@]}"; do
    [[ -f "$m" ]] || continue
    dir="$(dirname "$m")"
    while IFS= read -r line; do
      line="${line%%#*}"
      [[ "$line" == *:* ]] || continue
      fname="${line%%:*}"
      fname="${fname#"${fname%%[![:space:]]*}"}"
      fname="${fname%"${fname##*[![:space:]]}"}"
      themes=" ${line#*:} "
      if [[ "$themes" == *" $theme "* && -f "$dir/$fname" ]]; then
        printf '%s\n' "$dir/$fname"
      fi
    done < "$m"
  done
}

# wallpapers_all [include_local]
# Emits every image file under $WALLPAPERS_DIR (the matugen pool),
# sorted. local/ is excluded unless include_local is non-empty.
wallpapers_all() {
  local include_local="${1:-}"
  local filter=(! -path '*/local/*')
  [[ -n "$include_local" ]] && filter=()
  find -L "$WALLPAPERS_DIR" -type f ${filter[@]+"${filter[@]}"} \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | sort
}
