#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGE="$SCRIPT_DIR/files/wt-merge.py"
FRAGMENT="$SCRIPT_DIR/files/wt-fragment.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fixture: an existing settings.json with user content that must survive.
cat > "$tmp/settings.json" <<'JSON'
{
    "copyOnSelect": true,
    "keybindings": [ { "id": "User.find", "keys": "ctrl+shift+f" } ],
    "profiles": {
        "defaults": { "font": { "face": "Consolas" }, "cursorShape": "vintage" },
        "list": [ { "name": "PowerShell" } ]
    },
    "schemes": [ { "name": "Campbell", "background": "#0C0C0C" } ]
}
JSON

out="$(python3 "$MERGE" "$FRAGMENT" "$tmp/settings.json")"

# 1. User keys preserved.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["copyOnSelect"] is True; assert d["keybindings"][0]["keys"]=="ctrl+shift+f"; assert any(p.get("name")=="PowerShell" for p in d["profiles"]["list"])'
# 2. defaults deep-merged: our keys win, unrelated user default preserved is NOT required (cursorShape is one of ours -> overridden to "bar"), but list survives.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); dd=d["profiles"]["defaults"]; assert dd["font"]["face"]=="CaskaydiaCove Nerd Font"; assert dd["font"]["size"]==11; assert dd["colorScheme"]=="Catppuccin Mocha"; assert dd["cursorShape"]=="bar"'
# 3. launchMode set.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["launchMode"]=="focus"'
# 4. scheme upserted, existing Campbell untouched, no duplicate Catppuccin.
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); names=[s["name"] for s in d["schemes"]]; assert names.count("Catppuccin Mocha")==1; assert "Campbell" in names; m=[s for s in d["schemes"] if s["name"]=="Catppuccin Mocha"][0]; assert m["background"]=="#1E1E2E"'

# 5. Re-running on the merged output is a no-op (idempotent).
echo "$out" > "$tmp/merged.json"
out2="$(python3 "$MERGE" "$FRAGMENT" "$tmp/merged.json")"
[ "$out" = "$out2" ] || { echo "FAIL: merge not idempotent"; exit 1; }

# 6. Unparseable settings.json fails loud.
echo "{ not json" > "$tmp/bad.json"
if python3 "$MERGE" "$FRAGMENT" "$tmp/bad.json" 2>/dev/null; then echo "FAIL: bad json did not error"; exit 1; fi

echo "ALL MERGE TESTS PASSED"
