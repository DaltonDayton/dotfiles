#!/bin/bash
# Counts pending repo (checkupdates) + AUR (yay -Qua) updates.
# Wrapped in flock + short cache so the parallel waybar instances on
# multi-monitor setups don't fight over the checkupdates temp-db lock.

cache="${XDG_RUNTIME_DIR:-/tmp}/waybar-pacman-count"
ttl=60

(
  flock -x 9
  if [[ -f $cache && $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt $ttl ]]; then
    cat "$cache"
  else
    repo=$(checkupdates 2>/dev/null | wc -l)
    aur=$(yay -Qua 2>/dev/null | wc -l)
    printf '%s\n' "$((repo + aur))" | tee "$cache"
  fi
) 9>"$cache.lock"
