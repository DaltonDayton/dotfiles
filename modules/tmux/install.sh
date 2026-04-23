#!/usr/bin/env bash
set -euo pipefail

TPM="$HOME/.tmux/plugins/tpm"

# Only bootstrap when TPM is missing. After that, plugin management is
# TPM's job — `prefix + I` inside tmux picks up anything new.
if [ -d "$TPM" ]; then
    exit 0
fi

echo "Cloning TPM to $TPM"
git clone https://github.com/tmux-plugins/tpm "$TPM"
"$TPM/bin/install_plugins"
