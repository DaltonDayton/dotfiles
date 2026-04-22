#!/usr/bin/env bash
set -euo pipefail

current="$(getent passwd "$USER" | cut -d: -f7)"
target="$(command -v zsh)"

[ "$current" = "$target" ] && exit 0

echo "Setting login shell to $target"
sudo chsh -s "$target" "$USER"
