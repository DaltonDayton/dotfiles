#!/usr/bin/env bash
set -euo pipefail

case "$QUILL_OS" in
  arch)
    : # uv comes from the pacman block
    ;;
  ubuntu)
    export PATH="$HOME/.local/bin:$PATH"
    # uv is not in the Ubuntu 24.04 repos; install via Astral's official script
    # (standalone binary into ~/.local/bin, self-updating via `uv self update`).
    command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac
