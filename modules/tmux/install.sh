#!/usr/bin/env bash
set -euo pipefail

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Copy of the helper from modules/shell/install.sh (per the copy-paste policy).
# Downloads the latest GitHub release asset matching $2 (a grep -E pattern) from
# repo $1 into $LOCAL_BIN, extracting tar.gz/zip and copying out binaries $3...
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
    : # gum from pacman, sesh from aur, fd from pacman
    ;;
  ubuntu)
    command -v gum >/dev/null || \
      fetch_gh_release "charmbracelet/gum" 'gum_.*_Linux_x86_64\.tar\.gz' gum
    command -v sesh >/dev/null || \
      fetch_gh_release "joshmedeski/sesh" 'sesh_Linux_x86_64\.tar\.gz' sesh
    # fd ships as `fdfind` on Ubuntu; expose it under the expected name.
    if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
      ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
    fi
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac

# TPM bootstrap — OS-agnostic, runs on both Arch and Ubuntu.
TPM="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM" ]; then
    exit 0
fi
echo "Cloning TPM to $TPM"
git clone https://github.com/tmux-plugins/tpm "$TPM"
"$TPM/bin/install_plugins"
