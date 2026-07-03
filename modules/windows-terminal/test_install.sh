#!/usr/bin/env bash
# Regression tests for install.sh's bash control flow: the skip path, the font
# download/idempotency paths, the settings merge with backup, and the fail-loud
# path on unparseable JSON. These cover the scenarios that surfaced as bugs
# during development (set -e skip abort, EXIT-trap tmp scope, no-op reruns).
#
# Isolation: QUILL_WT_GLOB redirects the settings search to a fixture tree, and
# a stub bin dir on PATH shadows curl/unzip/reg.exe so nothing touches the
# network, the real Windows fonts dir, or the real registry.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/install.sh"
WEIGHTS=(Regular Bold Italic BoldItalic)

pass=0
fail() { echo "FAIL: $1"; exit 1; }

# Build a stub bin dir. curl touches its -o target; unzip creates the extract
# dir with the four ttf files install.sh copies; reg.exe is a no-op.
# Scope note: these stubs verify install.sh's control flow, not font-artifact
# correctness. The real CascadiaCode.zip layout, member filenames, and a bad
# NERD_FONTS_VERSION (404) are covered only by the manual E2E smoke test.
make_stubs() {
  local bin="$1"
  mkdir -p "$bin"
  cat > "$bin/curl" <<'SH'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
[ -n "$out" ] && : > "$out"
exit 0
SH
  cat > "$bin/unzip" <<'SH'
#!/usr/bin/env bash
dest=""; prev=""
for a in "$@"; do [ "$prev" = "-d" ] && dest="$a"; prev="$a"; done
mkdir -p "$dest"
for w in Regular Bold Italic BoldItalic; do : > "$dest/CaskaydiaCoveNerdFont-$w.ttf"; done
exit 0
SH
  cat > "$bin/reg.exe" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$bin/curl" "$bin/unzip" "$bin/reg.exe"
}

# Create a fixture WT tree under $1, echo the settings.json path. $2 = settings
# body (default: minimal valid file with user content to preserve).
make_tree() {
  local root="$1" body="${2-}"
  local ls="$root/mnt/c/Users/tester/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
  mkdir -p "$ls"
  if [ -z "$body" ]; then
    body='{ "copyOnSelect": true, "profiles": { "defaults": { "cursorHeight": 20 }, "list": [ { "name": "PowerShell" } ] }, "schemes": [] }'
  fi
  printf '%s\n' "$body" > "$ls/settings.json"
  echo "$ls/settings.json"
}

fonts_dir_for() { echo "${1%%/AppData/*}/AppData/Local/Microsoft/Windows/Fonts"; }

# Run install.sh in an isolated env. Args: glob, stubbin. Echoes nothing;
# sets globals RC and OUT.
run() {
  local glob="$1" bin="$2"
  set +e
  OUT="$(QUILL_WT_GLOB="$glob" PATH="$bin:$PATH" bash "$INSTALL" 2>&1)"
  RC=$?
  set -e
}

# --- 1. No Windows Terminal -> clean skip, exit 0 -----------------------------
t="$(mktemp -d)"; bin="$t/bin"; make_stubs "$bin"
run "$t/nonexistent/*/settings.json" "$bin"
[ "$RC" -eq 0 ] || fail "no-WT: expected exit 0, got $RC"
echo "$OUT" | grep -q "Windows Terminal not found, skipping." || fail "no-WT: missing skip message"
rm -rf "$t"; pass=$((pass+1))

# --- 2. Download path: fonts absent -> download, install, merge, exit 0 -------
t="$(mktemp -d)"; bin="$t/bin"; make_stubs "$bin"
settings="$(make_tree "$t")"
run "$settings" "$bin"
[ "$RC" -eq 0 ] || fail "download: expected exit 0, got $RC ($OUT)"
echo "$OUT" | grep -q "font installed." || fail "download: missing install message"
fd="$(fonts_dir_for "$settings")"
for w in "${WEIGHTS[@]}"; do
  [ -f "$fd/CaskaydiaCoveNerdFont-$w.ttf" ] || fail "download: $w ttf not copied"
done
rm -rf "$t"; pass=$((pass+1))

# --- 3. Fonts already present -> skip download step, exit 0 -------------------
t="$(mktemp -d)"; bin="$t/bin"; make_stubs "$bin"
settings="$(make_tree "$t")"
fd="$(fonts_dir_for "$settings")"; mkdir -p "$fd"
for w in "${WEIGHTS[@]}"; do : > "$fd/CaskaydiaCoveNerdFont-$w.ttf"; done
# Make curl a hard failure so a regressed font-present check that tries to
# download fails deterministically offline (the real curl is still on PATH).
cat > "$bin/curl" <<'SH'
#!/usr/bin/env bash
echo "curl should not run when fonts are already present" >&2
exit 1
SH
chmod +x "$bin/curl"
run "$settings" "$bin"
[ "$RC" -eq 0 ] || fail "font-present: expected exit 0, got $RC ($OUT)"
echo "$OUT" | grep -q "font already installed." || fail "font-present: missing skip message"
rm -rf "$t"; pass=$((pass+1))

# --- 4/5. Merge writes once + backup, rerun is a true no-op -------------------
t="$(mktemp -d)"; bin="$t/bin"; make_stubs "$bin"
settings="$(make_tree "$t")"
# Run 1: applies, writes backup.
run "$settings" "$bin"
[ "$RC" -eq 0 ] || fail "merge: run1 expected exit 0, got $RC ($OUT)"
echo "$OUT" | grep -q "settings.json updated" || fail "merge: run1 did not update"
[ -f "$settings.quill-backup" ] || fail "merge: backup not created"
# User content preserved; our keys applied.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["copyOnSelect"] is True; assert any(p.get("name")=="PowerShell" for p in d["profiles"]["list"]); assert d["profiles"]["defaults"]["cursorHeight"]==20; assert d["profiles"]["defaults"]["colorScheme"]=="Catppuccin Mocha"; assert d["launchMode"]=="focus"; assert any(s["name"]=="Catppuccin Mocha" for s in d["schemes"])' "$settings" || fail "merge: content assertions failed"
backup_sum="$(md5sum "$settings.quill-backup")"
# Run 2: no-op.
run "$settings" "$bin"
[ "$RC" -eq 0 ] || fail "merge: run2 expected exit 0, got $RC ($OUT)"
echo "$OUT" | grep -q "already up to date." || fail "merge: run2 not a no-op"
[ "$(md5sum "$settings.quill-backup")" = "$backup_sum" ] || fail "merge: backup rewritten on rerun"
rm -rf "$t"; pass=$((pass+2))  # covers write-with-backup and no-op rerun

# --- 6. Unparseable settings.json -> exit 1, file untouched, no backup --------
t="$(mktemp -d)"; bin="$t/bin"; make_stubs "$bin"
settings="$(make_tree "$t" '{ this is not json')"
fd="$(fonts_dir_for "$settings")"; mkdir -p "$fd"
for w in "${WEIGHTS[@]}"; do : > "$fd/CaskaydiaCoveNerdFont-$w.ttf"; done  # skip download
before="$(cat "$settings")"
run "$settings" "$bin"
[ "$RC" -eq 1 ] || fail "bad-json: expected exit 1, got $RC ($OUT)"
[ "$(cat "$settings")" = "$before" ] || fail "bad-json: settings file was mutated"
[ -f "$settings.quill-backup" ] && fail "bad-json: backup should not exist"
rm -rf "$t"; pass=$((pass+1))

echo "ALL INSTALL TESTS PASSED ($pass/6)"
