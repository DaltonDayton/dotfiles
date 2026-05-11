#!/usr/bin/env bash
set -euo pipefail

# OpenRazer's udev rules grant /dev/hidraw* access to the 'openrazer' group;
# the daemon refuses to start unless the running user is a member.
if ! id -nG "$USER" | grep -qw openrazer; then
  sudo gpasswd -a "$USER" openrazer
  # Reboot, not just relogin: the systemd --user manager only picks up new
  # groups when it fully exits, which requires ending every session for the
  # user (TTY, GUI, SSH). A reboot is the reliable way.
  echo "razer: added $USER to 'openrazer' group — REBOOT to activate (relogin alone is not enough)"
fi

# Load kernel modules now so a freshly-installed system can talk to an
# attached device without a reboot. Subsequent boots auto-load via the
# modaliases shipped by openrazer-driver-dkms.
for mod in razermouse razerkbd razeraccessory; do
  if ! lsmod | awk '{print $1}' | grep -qx "$mod"; then
    sudo modprobe "$mod"
  fi
done

# Reapply udev so already-attached devices pick up the openrazer group and
# trigger the modaliases for the just-loaded modules.
sudo udevadm control --reload-rules
sudo udevadm trigger
