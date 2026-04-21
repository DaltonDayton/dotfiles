#!/usr/bin/env bash
# Idempotent: exits 0 if yay is already installed.
set -euo pipefail

command -v yay >/dev/null && exit 0

# Fast path: use paru if it's already here.
if command -v paru >/dev/null; then
    paru -S --needed --noconfirm --skipreview yay
    exit 0
fi

# Cold path: build from the AUR via makepkg.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone https://aur.archlinux.org/yay.git "$tmp/yay"
cd "$tmp/yay"
makepkg -si --noconfirm
