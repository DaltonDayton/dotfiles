#!/usr/bin/env bash
set -euo pipefail

case "$QUILL_OS" in
  arch)
    : # opencode + claude-code come from pacman/aur
    ;;
  ubuntu)
    # claude + opencode install as global npm packages on asdf-managed node.
    # asdf 0.16+ is a Go binary with shims under ~/.asdf/shims; the asdf binary
    # itself was `go install`ed by the asdf module, so include ~/go/bin too.
    export PATH="$HOME/.asdf/shims:$HOME/go/bin:$PATH"

    # Query npm's global list directly — more reliable than PATH/shim probing,
    # which is racy before `asdf reshim`.
    npm_global_has() { npm ls -g --depth=0 "$1" >/dev/null 2>&1; }
    npm_global_has @anthropic-ai/claude-code || npm i -g @anthropic-ai/claude-code
    npm_global_has opencode-ai || npm i -g opencode-ai

    # Expose the freshly-installed bins as asdf shims (~/.asdf/shims/claude etc.).
    asdf reshim nodejs
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac
