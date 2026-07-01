#!/usr/bin/env bash

# Show explicitly installed packages (not dependencies) sorted by most recent
comm -12 \
        <(pacman -Qent | awk '{print $1}' | sort) \
        <(grep '\[ALPM\] installed' /var/log/pacman.log* | awk '{for (i=1;i<=NF;i++) if ($i=="installed") print $(i+1)}' | sort) |
        while read pkg; do
                grep -h "\[ALPM\] installed $pkg " /var/log/pacman.log* | tail -1
        done | sort -r
