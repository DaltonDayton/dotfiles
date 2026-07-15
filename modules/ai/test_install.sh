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
  QUILL_CLAUDE_SNAP="$root/snap.json" \
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

# Case 4: legacy setup — out.json is a symlink to the base (pre-overlay
# machines). Even when merged == base, the symlink must become a real file.
t4="$(mktemp -d)"
jq -n '{ model: "fable", enabledPlugins: { p1: true } }' > "$t4/base.json"
ln -s "$t4/base.json" "$t4/out.json"
run "$t4"
[ ! -L "$t4/out.json" ] || fail "legacy symlink not replaced by real file"
[ "$(jq -r '.model' "$t4/out.json")" = "fable" ] || fail "migrated output lost base content"
[ "$(jq -r '.model' "$t4/base.json")" = "fable" ] || fail "base clobbered during migration"
pass=$((pass+1))

# Case 5: legacy symlink plus a local overlay — the merge must never leak
# through the link into the tracked base.
t5="$(mktemp -d)"
jq -n '{ model: "fable" }' > "$t5/base.json"
cat > "$t5/local.json" <<'JSON'
{ "model": "opus" }
JSON
ln -s "$t5/base.json" "$t5/out.json"
run "$t5"
[ ! -L "$t5/out.json" ] || fail "legacy symlink not replaced (overlay case)"
[ "$(jq -r '.model' "$t5/out.json")" = "opus" ] || fail "overlay not merged after migration"
[ "$(jq -r '.model' "$t5/base.json")" = "fable" ] || fail "merge leaked through symlink into base"
pass=$((pass+1))

# Case 6: runtime drift in the generated file blocks regeneration (fail loud,
# nothing clobbered) and names the drift.
t6="$(mktemp -d)"
jq -n '{ model: "fable" }' > "$t6/base.json"
run "$t6"
jq '.alwaysThinkingEnabled = true' "$t6/out.json" > "$t6/edited.json"
mv "$t6/edited.json" "$t6/out.json"
drifted="$(cat "$t6/out.json")"
jq -n '{ model: "fable", theme: "auto" }' > "$t6/base.json"
if err="$(run "$t6" 2>&1)"; then fail "drifted output regenerated without complaint"; fi
[ "$(cat "$t6/out.json")" = "$drifted" ] || fail "drifted output was clobbered"
printf '%s' "$err" | grep -q "alwaysThinkingEnabled" || fail "drift diff does not show the edit"
pass=$((pass+1))

# Case 7: QUILL_CLAUDE_FORCE=1 discards the drift and regenerates.
QUILL_CLAUDE_FORCE=1 run "$t6" || fail "force run failed"
[ "$(jq -r '.theme' "$t6/out.json")" = "auto" ] || fail "force did not regenerate from base"
[ "$(jq -r '.alwaysThinkingEnabled' "$t6/out.json")" = "null" ] || fail "force kept the drift"
pass=$((pass+1))

# Case 8: base update with no runtime drift regenerates without complaint.
t8="$(mktemp -d)"
jq -n '{ model: "fable" }' > "$t8/base.json"
run "$t8"
jq -n '{ model: "fable", theme: "auto" }' > "$t8/base.json"
run "$t8" || fail "clean base update was blocked"
[ "$(jq -r '.theme' "$t8/out.json")" = "auto" ] || fail "base update not applied"
pass=$((pass+1))

echo "ok ($pass cases)"
