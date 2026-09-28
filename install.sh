#!/usr/bin/env bash
# Symlink config/ → ~/.config and home/ → ~. Safe to rerun.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)

link() { # <src> <dst>: move a real file aside, then link
  mkdir -p "$(dirname "$2")"
  if [[ -e $2 && ! -L $2 ]]; then mv "$2" "$2.bak.$(date +%s)"; fi
  ln -sfn "$1" "$2"
}

link "$repo/config/nvim" ~/.config/nvim   # whole dir: lazy.nvim writes into it

find "$repo/config" "$repo/home" -type f \
  -not -path '*/config/nvim/*' -not -name 'monitors.*.lua' -not -path '*/git/personal' |
while read -r f; do
  rel=${f#"$repo"/}
  case $rel in
    config/*) link "$f" ~/.config/"${rel#config/}" ;;
    home/*)   link "$f" ~/"${rel#home/}" ;;
  esac
done

mon="$repo/config/hypr/monitors.$(hostname).lua"
if [[ -e $mon ]]; then link "$mon" ~/.config/hypr/monitors.lua; else echo "no monitors.$(hostname).lua, keeping Omarchy's"; fi

# git has no drop-in dir, so include ours from Omarchy's config instead of replacing it.
grep -qF "$repo/config/git/personal" ~/.config/git/config 2>/dev/null ||
  printf '\n[include]\n\tpath = %s\n' "$repo/config/git/personal" >> ~/.config/git/config

"$repo/packages.sh"
