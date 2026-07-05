#!/usr/bin/env bash
# Mounts the two NTFS data HDDs via fstab. Uses the in-kernel ntfs3 driver
# (no extra packages). UUIDs are stable across OS reinstalls — they only
# change if the drives themselves are reformatted.
set -euo pipefail

add_mount() {
  local uuid="$1" mountpoint="$2"
  local line="UUID=${uuid}  ${mountpoint}  ntfs3  rw,uid=1000,gid=1000,umask=022,nofail,x-systemd.device-timeout=10  0 0"

  sudo mkdir -p "$mountpoint"
  if ! grep -q "^UUID=${uuid}\b" /etc/fstab; then
    printf '%s\n' "$line" | sudo tee -a /etc/fstab >/dev/null
    sudo systemctl daemon-reload
  fi
  # nofail in fstab, and the drive may legitimately be unplugged — warn, don't abort
  if ! mountpoint -q "$mountpoint"; then
    sudo mount "$mountpoint" \
      || echo "warning: could not mount $mountpoint (drive missing?)" >&2
  fi
}

add_mount F046EFB246EF77AC /mnt/4TB_HDD
add_mount B0FE0DF2FE0DB1A0 /mnt/1TB_HDD
