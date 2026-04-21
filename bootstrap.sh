#!/usr/bin/env bash
# Fresh-install entry point for quill.
# Designed to be piped via: curl -fsSL <url>/bootstrap.sh | bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/DaltonDayton/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

echo "==> Installing prerequisites (git, go, base-devel)"
sudo pacman -Sy --needed --noconfirm git go base-devel

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "==> Cloning $REPO_URL into $REPO_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
else
    echo "==> Updating existing clone at $REPO_DIR"
    git -C "$REPO_DIR" pull --ff-only
fi

echo "==> Building quill"
cd "$REPO_DIR"
go build -o ./bin/quill ./cmd/quill

echo "==> Launching interactive installer"
exec ./bin/quill install
