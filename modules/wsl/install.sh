#!/usr/bin/env bash
# Drop a minimal wslview shim so browser-opening (az login, xdg-open) works on
# WSL, where Ubuntu 26.04 dropped wslu from its repos. WSL-only: off WSL this is
# a clean no-op, keeping the module portable to bare-Ubuntu profiles.
set -euo pipefail

: "${QUILL_PROC_VERSION:=/proc/version}"
: "${QUILL_LOCAL_BIN:=$HOME/.local/bin}"

SHIM="$QUILL_LOCAL_BIN/wslview"

grep -qiE microsoft "$QUILL_PROC_VERSION" 2>/dev/null || exit 0

# Skip if a real wslview (anything other than our own shim) is on PATH — Ubuntu
# may restore wslu, which should win.
existing="$(command -v wslview 2>/dev/null || true)"
[ -n "$existing" ] && [ "$existing" != "$SHIM" ] && exit 0

read -r -d '' body <<'EOF' || true
#!/bin/sh
# Minimal wslview: open URL/path in Windows default browser (wslu unavailable
# on Ubuntu 26.04).
exec powershell.exe -NoProfile -Command "Start-Process '$*'" </dev/null >/dev/null 2>&1
EOF

# A symlinked shim path is always replaced, never compared or written through.
[ -L "$SHIM" ] && rm "$SHIM"

if [ -f "$SHIM" ] && [ "$(cat "$SHIM")" = "$body" ]; then
  exit 0
fi

mkdir -p "$QUILL_LOCAL_BIN"
# Write via temp + rename so a partial write can never corrupt the shim in place.
tmp="$(mktemp "$QUILL_LOCAL_BIN/.wslview.XXXXXX")"
printf '%s\n' "$body" > "$tmp"
chmod +x "$tmp"
mv "$tmp" "$SHIM"
