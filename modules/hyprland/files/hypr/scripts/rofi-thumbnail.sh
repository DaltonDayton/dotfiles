#!/usr/bin/env bash
set -euo pipefail

input="${1:-}"
output="${2:-}"
size="${3:-210}"
thumb_w="${4:-280}"
thumb_h="${5:-158}"

src="${input%%\?*}"
src="${src%%\#*}"

size="${size%%.*}"
if [[ ! "$size" =~ ^[0-9]+$ ]] || (( size <= 0 )); then
  size=210
fi

thumb_w="${thumb_w%%.*}"
thumb_h="${thumb_h%%.*}"
if [[ ! "$thumb_w" =~ ^[0-9]+$ ]] || (( thumb_w <= 0 )); then
  thumb_w=280
fi
if [[ ! "$thumb_h" =~ ^[0-9]+$ ]] || (( thumb_h <= 0 )); then
  thumb_h=158
fi

if ! ffmpeg -hide_banner -loglevel error -y -i "$src" \
  -vf "scale=${thumb_w}:${thumb_h}:force_original_aspect_ratio=increase:flags=lanczos,crop=${thumb_w}:${thumb_h}" \
  -frames:v 1 "$output"; then
  cp "$src" "$output"
fi
