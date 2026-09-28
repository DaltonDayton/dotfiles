#!/usr/bin/env bash
# Packages this setup needs on top of Omarchy's own. Safe to rerun.
set -euo pipefail

REPO_PKGS=(
  playerctl    # voxtype pauses media while recording
  whisper-cpp  # yt-transcript
  ggml-vulkan  # GPU backend for whisper-cpp
  ggml-cpu     # whisper-cpp needs it even in GPU mode
  nfs-utils    # media export to pve for Jellyfin
)

AUR_PKGS=(
  wayland-pipewire-idle-inhibit  # hypr/autostart.lua
  bibata-cursor-git              # hypr/looknfeel.lua
)

# <plugin id>:<git url>, placed in the bar by omarchy/shell.json.
SHELL_PLUGINS=(
  crmne.hyprmoncfg:https://github.com/crmne/omarchy-hyprmoncfg.git
  bitr0t.system-monitor:https://github.com/rmacy/omarchy-system-monitor.git
)

missing() { for p in "$@"; do pacman -Q "$p" &>/dev/null || echo "$p"; done; }

mapfile -t want < <(missing "${REPO_PKGS[@]}")
(( ${#want[@]} )) && omarchy-pkg-add "${want[@]}"

mapfile -t want < <(missing "${AUR_PKGS[@]}")
(( ${#want[@]} )) && omarchy-pkg-aur-add "${want[@]}"

for entry in "${SHELL_PLUGINS[@]}"; do
  id=${entry%%:*} url=${entry#*:}
  [[ -e ~/.config/omarchy/plugins/$id ]] && continue
  # Exits nonzero when the shell isn't running yet, so check the clone instead.
  omarchy-plugin-add "$url" --yes || true
  [[ -e ~/.config/omarchy/plugins/$id ]] || { echo "failed to install plugin $id" >&2; exit 1; }
done
