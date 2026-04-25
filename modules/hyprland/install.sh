#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Matugen first-run render --------------------------------------
# Skip if colors already exist — runtime theme swaps go through a separate
# user-bound script that calls matugen directly. Quill never re-renders.
if [[ ! -f "$HOME/.config/hypr/colors/matugen.conf" ]]; then
  matugen image "$MODULE_DIR/files/wallpapers/default.png"
fi
