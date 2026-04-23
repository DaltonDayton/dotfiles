#!/usr/bin/env bash
set -euo pipefail

for plugin in nodejs ruby; do
    if ! asdf plugin list 2>/dev/null | grep -qx "$plugin"; then
        echo "Adding asdf plugin: $plugin"
        asdf plugin add "$plugin"
    fi

    latest="$(asdf latest "$plugin")"
    # asdf install no-ops when the version is already present.
    asdf install "$plugin" "$latest"
    asdf set -u "$plugin" "$latest"
done
