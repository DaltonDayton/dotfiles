#!/usr/bin/env bash
set -euo pipefail

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Download the latest GitHub release asset whose name matches $2 (a grep -E
# pattern) from repo $1, into $LOCAL_BIN. Extracts tar.gz or zip; copies the
# named binaries ($3...) out. Idempotent callers guard with `command -v`.
fetch_gh_release() {
  repo="$1"; asset_re="$2"; shift 2
  # `|| true`: grep exits non-zero on no match, which set -e would otherwise
  # treat as fatal before the guard below runs.
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oE "https://[^\"]*$asset_re" | head -n1 || true)"
  [ -n "$url" ] || { echo "no release asset for $repo matching $asset_re" >&2; return 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  file="$tmp/$(basename "$url")"
  curl -fsSL "$url" -o "$file"
  case "$file" in
    *.tar.gz|*.tgz) tar -xzf "$file" -C "$tmp" ;;
    *.zip)          unzip -q "$file" -d "$tmp" ;;
  esac
  for bin in "$@"; do
    # -print -quit stops at the first match without SIGPIPE (a `| head` pipe
    # would SIGPIPE find, which pipefail+set -e would treat as fatal).
    found="$(find "$tmp" -type f -name "$bin" -perm -u+x -print -quit)"
    [ -n "$found" ] || found="$(find "$tmp" -type f -name "$bin" -print -quit)"
    if [ -n "$found" ]; then
      install -m755 "$found" "$LOCAL_BIN/$bin"
    else
      echo "warning: $bin not found in $repo archive" >&2
    fi
  done
}

case "$QUILL_OS" in
  arch)
    : # pacman block installed everything
    ;;
  ubuntu)
    command -v unzip >/dev/null || sudo apt-get install -y unzip

    command -v starship >/dev/null || \
      curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"

    command -v zoxide >/dev/null || \
      curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

    command -v atuin >/dev/null || \
      curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

    command -v eza >/dev/null || \
      fetch_gh_release "eza-community/eza" 'eza_x86_64-unknown-linux-gnu\.tar\.gz' eza

    command -v yazi >/dev/null || \
      fetch_gh_release "sxyazi/yazi" 'yazi-x86_64-unknown-linux-gnu\.zip' yazi ya

    # bat ships as `batcat` on Ubuntu; expose it under the expected name.
    if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
      ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
    fi
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac

current="$(getent passwd "$USER" | cut -d: -f7)"
target="$(command -v zsh)"

[ "$current" = "$target" ] && exit 0

echo "Setting login shell to $target"
sudo chsh -s "$target" "$USER"
