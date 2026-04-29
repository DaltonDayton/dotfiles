#!/usr/bin/env bash
set -euo pipefail

for plugin in nodejs ruby; do
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
