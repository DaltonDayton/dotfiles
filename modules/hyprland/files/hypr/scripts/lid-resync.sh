#!/usr/bin/env bash
# Re-sync eDP-1 with the actual lid position. Hyprland's lid switch events
# are edge-triggered and get lost across suspend (wake and lid-open land
# while userspace is still frozen), which left the panel disabled after
# resume. hypridle runs this as after_sleep_cmd; the switch:off binding
# also calls it so the re-enable logic lives in one place.
set -euo pipefail

if grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    hyprctl keyword monitor "eDP-1, disable"
else
    hyprctl keyword monitor "eDP-1, preferred, auto, 2"
fi
hyprctl dispatch dpms on
