#!/usr/bin/env bash
set -euo pipefail

usage=$(top -bn1 | awk -F'id,' '/Cpu\(s\)/ {split($1,a,","); gsub(/^[[:space:]]+/, "", a[length(a)]); printf "%3.0f", 100-a[length(a)]}')

temp=""
if command -v sensors >/dev/null 2>&1; then
  temp=$(sensors 2>/dev/null | awk '/Tctl:|Package id 0:/ {gsub(/[^0-9.+-]/, "", $2); printf "%d", $2; exit}')
fi

if [[ -z "$temp" ]]; then
  printf '󰍛 %s%%\n' "$usage"
else
  printf '󰍛 %s%% %sC\n' "$usage" "$temp"
fi
