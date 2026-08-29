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
  wayland-pipewire-idle-inhibit  # Wayland idle inhibitor while audio plays -- config/hypr/autostart.lua
  bibata-cursor-git              # cursor theme (hyprcursor + Xcursor) -- config/hypr/looknfeel.lua
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

# Dev toolchains -- reported, never installed here
# ------------------------------------------------
# `omarchy install dev-env <name>` does more than drop a binary: ruby also gets
# rails and ~/.gemrc, python also gets uv. Reproducing that here would drift
# from the installer, so this only reports what's missing and points at the
# command. One-time per machine.
#
# Entries are <dev-env name>:<command to probe>:<mise|any>. The mise flag
# matters because Omarchy's base install ships its own ruby
# (omarchy-base.packages), so a bare `command -v ruby` would never notice that
# `omarchy install dev-env ruby` had not been run. Toolchains the installer
# does not route through mise (rust via rustup, php via pacman) use `any`.
# Anything from `omarchy install dev-env` with no argument can be added here.
DEV_ENVS=(
  go:go:mise          # mason: gopls, goimports, gofumpt, delve
  node:node:mise      # mason: ts_ls, eslint, prettier, pyright, emmet, html, cssls
  python:python:mise  # mason: black, isort, pylint, debugpy
  ruby:ruby:mise      # mason: ruby_lsp, rubocop
  dotnet:dotnet:mise  # mason: csharp_ls
)

MISE_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"

needs_dev_env() { # <command> <mise|any> -- true when it still needs installing
  local cmd="$1" how="$2" path
  path="$(command -v "$cmd" 2>/dev/null)" || return 0
  [[ -n "$path" ]] || return 0
  [[ "$how" == "mise" && "$path" != "$MISE_DIR"/* ]] && return 0
  return 1
}

report_dev_envs() {
  local entry name cmd how found=0
  for entry in "${DEV_ENVS[@]}"; do
    IFS=: read -r name cmd how <<<"$entry"
    needs_dev_env "$cmd" "$how" || continue
    found=$((found + 1))
    printf '  missing toolchain: %-7s run: omarchy install dev-env %s\n' "$name" "$name"
  done
  (( found )) && printf '  %d toolchain(s) above are a one-time install per machine.\n' "$found"
  return 0
}

report_dev_envs
