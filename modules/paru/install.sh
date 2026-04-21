#!/usr/bin/env bash
# Idempotent: exits 0 if paru is already installed.
set -euo pipefail

command -v paru >/dev/null && exit 0

# Fast path: use yay if it's already here.
if command -v yay >/dev/null; then
    yay -S --needed --noconfirm paru
    exit 0
fi

# Cold path: build from the AUR via makepkg.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone https://aur.archlinux.org/paru.git "$tmp/paru"
cd "$tmp/paru"
makepkg -si --noconfirm
