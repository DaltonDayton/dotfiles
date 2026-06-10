#!/usr/bin/env bash
# Fresh-install entry point for quill.
# Designed to be piped via: curl -fsSL <url>/bootstrap.sh | bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/DaltonDayton/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
REPO_BRANCH="${DOTFILES_BRANCH:-main}"

echo "==> Installing prerequisites"
case "$(. /etc/os-release && echo "$ID")" in
  arch)
    sudo pacman -Sy --needed --noconfirm git go base-devel
    ;;
  ubuntu)
    sudo apt-get update
    sudo apt-get install -y git golang-go build-essential curl
    ;;
  *)
    echo "unsupported distro (need arch or ubuntu)" >&2
    exit 1
    ;;
esac

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "==> Cloning $REPO_URL (branch $REPO_BRANCH) into $REPO_DIR"
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
else
    echo "==> Updating existing clone at $REPO_DIR ($REPO_BRANCH)"
    git -C "$REPO_DIR" fetch origin "$REPO_BRANCH"
    git -C "$REPO_DIR" checkout "$REPO_BRANCH"
    git -C "$REPO_DIR" pull --ff-only origin "$REPO_BRANCH"
fi

echo "==> Building quill"
cd "$REPO_DIR"
go build -o ./bin/quill ./cmd/quill

echo "==> Launching interactive installer"
exec ./bin/quill install
