#!/usr/bin/env bash
# Post-resume re-sync, shared by hypridle's after_sleep_cmd and the lid
# switch:off binding so the re-enable logic lives in one place.
#
# Lid hosts: Hyprland's lid switch events are edge-triggered and get lost
# across suspend (wake and lid-open land while userspace is still frozen),
# which left the panel disabled after resume.
#
# Lidless hosts: plain "dpms on" is a no-op when Hyprland thinks the
# monitors are already on, leaving one stuck on the stale fbcon image
# after S3 wake. The off/on forces a real modeset on every head.
set -euo pipefail

if grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    hyprctl keyword monitor "eDP-1, disable"
    hyprctl dispatch dpms on
elif compgen -G '/proc/acpi/button/lid/*/state' >/dev/null; then
    hyprctl keyword monitor "eDP-1, preferred, auto, 2"
    hyprctl dispatch dpms on
else
    sleep 1
    hyprctl dispatch dpms off
    sleep 1
    hyprctl dispatch dpms on
fi
