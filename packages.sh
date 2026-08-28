#!/usr/bin/env bash
# Packages this setup needs on top of what Omarchy already installs.
#   ./packages.sh          install anything missing
#   ./packages.sh --dry    list what's missing, install nothing
#
# install.sh runs this at the end, so a fresh machine gets one command. Both
# are idempotent: when everything is present this does nothing at all and
# never asks for sudo.
#
# Installs go through omarchy-pkg-add / omarchy-pkg-aur-add rather than raw
# pacman/yay -- same path the rest of Omarchy uses. They're --needed, and they
# re-check with pacman -Q afterwards so a silent failure still exits nonzero.
#
# Only list what this repo's configs actually depend on, or what you'd be
# annoyed to be missing on a new box. Omarchy's own preinstalls don't belong
# here; it'll put those back itself.
set -euo pipefail

# Arch repos.
REPO_PKGS=(
)

# AUR. Slower and built from source, so keep this list short.
AUR_PKGS=(
  sway-audio-idle-inhibit-git   # idle inhibitor while audio plays -- config/hypr/autostart.lua
)

DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry) DRY=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if ! command -v omarchy-pkg-add >/dev/null; then
  echo "omarchy-pkg-add not found -- this script only runs on an Omarchy system." >&2
  exit 1
fi

missing() { # print the ones not installed, one per line
  local pkg
  for pkg in "$@"; do
    pacman -Q "$pkg" &>/dev/null || printf '%s\n' "$pkg"
  done
}

install_set() { # <installer> <label> <packages...>
  local installer="$1" label="$2"; shift 2
  (( $# )) || return 0

  local -a want
  mapfile -t want < <(missing "$@")
  (( ${#want[@]} )) || return 0

  local pkg
  if (( DRY )); then
    for pkg in "${want[@]}"; do printf '  would install %s (%s)\n' "$pkg" "$label"; done
    return 0
  fi

  for pkg in "${want[@]}"; do printf '  installing %s (%s)\n' "$pkg" "$label"; done
  "$installer" "${want[@]}"
}

install_set omarchy-pkg-add     repo "${REPO_PKGS[@]}"
install_set omarchy-pkg-aur-add aur  "${AUR_PKGS[@]}"
