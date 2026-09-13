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
# Omarchy shell plugins aren't packages at all; they get their own section
# below, on the same check-the-result principle.
#
# Only list what this repo's configs actually depend on, or what you'd be
# annoyed to be missing on a new box. Omarchy's own preinstalls don't belong
# here; it'll put those back itself.
set -euo pipefail

# Arch repos.
REPO_PKGS=(
  playerctl    # voxtype pauses media while recording; warns on every take without it
  whisper-cpp  # whisper-cli -- home/.local/bin/yt-transcript
  ggml-vulkan  # GPU backend for whisper-cli; ggml loads it at runtime
  ggml-cpu     # whisper.cpp asserts on a CPU device even in GPU mode; Arch splits it out
)

# AUR. Slower and built from source, so keep this list short.
AUR_PKGS=(
  wayland-pipewire-idle-inhibit  # Wayland idle inhibitor while audio plays -- config/hypr/autostart.lua
  bibata-cursor-git              # cursor theme (hyprcursor + Xcursor) -- config/hypr/looknfeel.lua
)

# Omarchy shell plugins. Git clones under ~/.config/omarchy/plugins/<id>, which
# this repo doesn't track -- shell.json tracks only where the widget sits in the
# bar, so without this a fresh machine gets the bar entry and nothing behind it.
#
# Entries are <plugin id>:<git url>. The id comes from the plugin's
# manifest.json and is the directory it lands in; it isn't derived from the URL,
# so it's spelled out rather than guessed.
SHELL_PLUGINS=(
  crmne.hyprmoncfg:https://github.com/crmne/omarchy-hyprmoncfg.git          # monitor config widget -- config/omarchy/shell.json
  bitr0t.system-monitor:https://github.com/rmacy/omarchy-system-monitor.git  # CPU chip + system monitor panel -- config/omarchy/shell.json
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

PLUGINS_DIR="$HOME/.config/omarchy/plugins"

install_shell_plugins() {
  local entry id url
  for entry in "${SHELL_PLUGINS[@]}"; do
    id="${entry%%:*}"; url="${entry#*:}"

    # omarchy-plugin-add refuses an id that's already installed, so skipping
    # here is what keeps a rerun quiet rather than fatal.
    [[ -e "$PLUGINS_DIR/$id" ]] && continue

    if (( DRY )); then printf '  would install %s (shell plugin)\n' "$id"; continue; fi
    printf '  installing %s (shell plugin)\n' "$id"

    # --yes skips the "plugins run unsandboxed" confirmation, which is the
    # point of pinning the URL here, and leaves the plugin disabled: shell.json
    # already places it, and letting the installer enable it too would just
    # fight the tracked file.
    #
    # It ends by pinging the running shell to rescan, which fails on a machine
    # where omarchy-shell isn't up yet -- a fresh install, exactly when this
    # matters. The clone has landed by then, so check for that instead of
    # trusting the exit status.
    omarchy-plugin-add "$url" --yes || true
    [[ -e "$PLUGINS_DIR/$id" ]] || { echo "failed to install shell plugin $id" >&2; exit 1; }
  done
}

install_shell_plugins

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
