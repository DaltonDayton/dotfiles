#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logitech Unifying udev rule (sudo) ----------------------------
# Symlinked into /etc/udev/rules.d/ so repo edits flow through without
# re-copying. Reload udev only when the link actually changed, so re-applies
# stay sudo-quiet.
RULE_SRC="$MODULE_DIR/files/udev/42-logitech-unify-permissions.rules"
RULE_DST="/etc/udev/rules.d/42-logitech-unify-permissions.rules"

if [[ "$(readlink "$RULE_DST" 2>/dev/null)" != "$RULE_SRC" ]]; then
  sudo ln -sfn "$RULE_SRC" "$RULE_DST"
  sudo udevadm control --reload-rules
fi
