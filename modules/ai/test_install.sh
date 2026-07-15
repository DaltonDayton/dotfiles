#!/usr/bin/env bash
# Regression tests for install.sh's jq overlay merge: local overrides a base
# scalar, nested objects deep-merge, an absent local file yields the base
# verbatim, and a second run is a no-op. Isolation: QUILL_OS=arch makes the
# package-install case a no-op, and QUILL_CLAUDE_* redirect base/local/out to a
# temp tree so nothing touches the real ~/.claude.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/install.sh"

pass=0
fail() { echo "FAIL: $1"; exit 1; }

run() {
  local root="$1"
  QUILL_OS=arch \
  QUILL_CLAUDE_BASE="$root/base.json" \
  QUILL_CLAUDE_LOCAL="$root/local.json" \
  QUILL_CLAUDE_OUT="$root/out.json" \
    bash "$INSTALL"
}

# Case 1: local overrides a base scalar, deep-merges nested objects.
t1="$(mktemp -d)"
cat > "$t1/base.json" <<'JSON'
{ "model": "fable", "env": { "A": "1" }, "enabledPlugins": { "p1": true } }
JSON
cat > "$t1/local.json" <<'JSON'
{ "model": "opus", "env": { "B": "2" }, "enabledPlugins": { "p2": true } }
JSON
run "$t1"
[ "$(jq -r '.model' "$t1/out.json")" = "opus" ] || fail "local scalar did not override base"
[ "$(jq -r '.env.A' "$t1/out.json")" = "1" ] || fail "base nested key lost"
[ "$(jq -r '.env.B' "$t1/out.json")" = "2" ] || fail "local nested key missing"
[ "$(jq -r '.enabledPlugins.p1' "$t1/out.json")" = "true" ] || fail "base plugin lost"
[ "$(jq -r '.enabledPlugins.p2' "$t1/out.json")" = "true" ] || fail "local plugin missing"
pass=$((pass+1))

# Case 2: absent local file yields the base verbatim (semantically equal).
t2="$(mktemp -d)"
cat > "$t2/base.json" <<'JSON'
{ "model": "fable", "enabledPlugins": { "p1": true } }
JSON
run "$t2"
[ "$(jq -S . "$t2/out.json")" = "$(jq -S . "$t2/base.json")" ] || fail "absent local did not yield base"
pass=$((pass+1))

# Case 3: idempotent second run leaves output byte-identical.
before="$(cat "$t1/out.json")"
run "$t1"
[ "$(cat "$t1/out.json")" = "$before" ] || fail "second run changed output"
pass=$((pass+1))

echo "ok ($pass cases)"
