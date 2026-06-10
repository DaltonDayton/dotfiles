#!/usr/bin/env bash
set -euo pipefail

case "$QUILL_OS" in
  arch)
    plugins="nodejs ruby"   # asdf-vm installed declaratively via aur
    ;;
  ubuntu)
    # asdf is a Go binary on the 0.16+ rewrite; go ships from bootstrap.
    command -v go >/dev/null || sudo apt-get install -y golang-go
    command -v asdf >/dev/null || go install github.com/asdf-vm/asdf/cmd/asdf@latest
    export PATH="$HOME/go/bin:$PATH"   # go install target, for this script run
    plugins="nodejs"
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac

for plugin in $plugins; do
    if ! asdf plugin list 2>/dev/null | grep -qx "$plugin"; then
        echo "Adding asdf plugin: $plugin"
        asdf plugin add "$plugin"
    fi

    latest="$(asdf latest "$plugin")"
    # `asdf install` no-ops when the version is present, but still prints
    # "version X of Y is already installed" — guard it explicitly so re-runs
    # stay silent. `asdf list` marks the active version with a leading `*`,
    # so strip leading spaces/asterisks before matching.
    if ! asdf list "$plugin" 2>/dev/null | sed 's/^[ *]*//' | grep -qx "$latest"; then
        asdf install "$plugin" "$latest"
    fi
    asdf set -u "$plugin" "$latest"
done
