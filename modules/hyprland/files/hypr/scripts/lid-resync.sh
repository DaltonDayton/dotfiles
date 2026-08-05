#!/usr/bin/env bash
# Post-resume re-sync, shared by hypridle's after_sleep_cmd and the lid
# switch:off binding so the re-enable logic lives in one place.
#
# Lid hosts: Hyprland's lid switch events are edge-triggered and get lost
# across suspend (wake and lid-open land while userspace is still frozen),
# which left the panel disabled after resume.
#
# Lidless hosts: plain dpms enable is a no-op when Hyprland thinks the
# monitors are already on, leaving one stuck on the stale fbcon image
# after S3 wake. The disable/enable cycle forces a real modeset on every
# head.
set -euo pipefail

dpms() {
    hyprctl dispatch "hl.dsp.dpms({ action = \"$1\" })"
}

if compgen -G '/proc/acpi/button/lid/*/state' >/dev/null; then
    if grep -q closed /proc/acpi/button/lid/*/state; then
        hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "disable" })'
    else
        hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })'
    fi
    dpms enable
else
    sleep 1
    dpms disable
    sleep 1
    dpms enable
fi
