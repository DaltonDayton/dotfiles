#!/usr/bin/env bash
set -euo pipefail

conf_src="$(dirname "$0")/files/20-hardening.conf"
conf_dst="/etc/ssh/sshd_config.d/20-hardening.conf"

# Install the hardening drop-in only when missing or changed, restarting sshd
# so a config change actually takes effect.
if ! cmp -s "$conf_src" "$conf_dst" 2>/dev/null; then
  sudo install -m 644 -o root -g root "$conf_src" "$conf_dst"
  sudo systemctl try-restart sshd
fi

# The declarative action only enables sshd (see module.toml); start it here
# where sudo is available.
if ! systemctl is-active --quiet sshd; then
  sudo systemctl start sshd
fi
