#!/usr/bin/env bash
set -euo pipefail

TPM="$HOME/.tmux/plugins/tpm"

if [ ! -d "$TPM" ]; then
    echo "Cloning TPM to $TPM"
    git clone https://github.com/tmux-plugins/tpm "$TPM"
fi

"$TPM/bin/install_plugins"
