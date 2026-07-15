#!/usr/bin/env bash
# Regression tests for the wslview shim: written under the WSL guard when no
# real wslview is on PATH, skipped when a real wslview exists, and a clean
# no-op when the guard does not match. Isolation: QUILL_PROC_VERSION points at
# a fixture file, QUILL_LOCAL_BIN at a temp dir, and PATH is controlled per case.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/install.sh"

pass=0
fail() { echo "FAIL: $1"; exit 1; }

# Case 1: WSL guard matches, no wslview on PATH -> shim written + executable.
t1="$(mktemp -d)"
printf 'Linux version 5.15 microsoft-standard-WSL2\n' > "$t1/procversion"
QUILL_PROC_VERSION="$t1/procversion" QUILL_LOCAL_BIN="$t1/bin" PATH="/usr/bin:/bin" \
  bash "$INSTALL"
[ -x "$t1/bin/wslview" ] || fail "shim not written/executable under WSL"
grep -q 'Start-Process' "$t1/bin/wslview" || fail "shim body wrong"
pass=$((pass+1))

# Case 2: a real wslview exists on PATH -> shim skipped.
t2="$(mktemp -d)"
printf 'Linux version 5.15 microsoft-standard-WSL2\n' > "$t2/procversion"
mkdir -p "$t2/realbin"; printf '#!/bin/sh\n' > "$t2/realbin/wslview"; chmod +x "$t2/realbin/wslview"
QUILL_PROC_VERSION="$t2/procversion" QUILL_LOCAL_BIN="$t2/bin" PATH="$t2/realbin:/usr/bin:/bin" \
  bash "$INSTALL"
[ ! -e "$t2/bin/wslview" ] || fail "shim written despite real wslview on PATH"
pass=$((pass+1))

# Case 3: guard does not match (not WSL) -> no-op.
t3="$(mktemp -d)"
printf 'Linux version 5.15 generic\n' > "$t3/procversion"
QUILL_PROC_VERSION="$t3/procversion" QUILL_LOCAL_BIN="$t3/bin" PATH="/usr/bin:/bin" \
  bash "$INSTALL"
[ ! -e "$t3/bin/wslview" ] || fail "shim written off WSL"
pass=$((pass+1))

# Case 4: shim path occupied by a stale symlink -> replaced with a real file,
# never written through.
t4="$(mktemp -d)"
printf 'Linux version 5.15 microsoft-standard-WSL2\n' > "$t4/procversion"
mkdir -p "$t4/bin"
printf 'stale target\n' > "$t4/target"
ln -s "$t4/target" "$t4/bin/wslview"
QUILL_PROC_VERSION="$t4/procversion" QUILL_LOCAL_BIN="$t4/bin" PATH="/usr/bin:/bin" \
  bash "$INSTALL"
[ ! -L "$t4/bin/wslview" ] || fail "stale symlink not replaced by real file"
[ -x "$t4/bin/wslview" ] || fail "replaced shim not executable"
[ "$(cat "$t4/target")" = "stale target" ] || fail "shim write leaked through symlink"
pass=$((pass+1))

echo "ok ($pass cases)"
