#!/usr/bin/env bash
set -euo pipefail

KEY="$HOME/.ssh/id_ed25519"

# .gitconfig sets commit.gpgsign=true with gpg.format=ssh using this key, so a
# fresh machine can't sign (or push over SSH) until it exists.
if [ -f "$KEY" ]; then
    exit 0
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Passphrase-less so signing works non-interactively (no agent in the runner).
echo "Generating SSH key at $KEY"
ssh-keygen -t ed25519 -f "$KEY" -N "" -C "$USER@$(uname -n)"

echo
echo "New public key — add it to GitHub (Settings → SSH and GPG keys):"
cat "${KEY}.pub"
