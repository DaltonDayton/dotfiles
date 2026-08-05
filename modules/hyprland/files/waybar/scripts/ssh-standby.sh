#!/usr/bin/env bash
# Toggle a systemd sleep inhibitor so the machine stays reachable over ssh
# while monitors still dpms off. State lives in the transient user unit.
set -euo pipefail

UNIT=ssh-standby.service

is_active() {
    systemctl --user is-active --quiet "$UNIT"
}

case "${1:-}" in
toggle)
    if is_active; then
        systemctl --user stop "$UNIT"
    else
        systemd-run --user --unit=ssh-standby \
            systemd-inhibit --what=sleep --who=ssh-standby \
            --why="remote ssh access" --mode=block sleep infinity
    fi
    ;;
status)
    if is_active; then
        printf '{"alt": "active", "class": "active", "tooltip": "Suspend blocked for ssh"}\n'
    else
        printf '{"alt": "inactive", "class": "inactive", "tooltip": "Suspend allowed"}\n'
    fi
    ;;
*)
    echo "usage: $0 {toggle|status}" >&2
    exit 1
    ;;
esac
