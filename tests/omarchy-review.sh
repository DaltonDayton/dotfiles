#!/usr/bin/env bash
# Behavior of ./omarchy-review against a fake Omarchy tree and a fake repo.
# Everything runs under a temp dir: OMARCHY_PATH, XDG_*_HOME and a stub
# omarchy-version on PATH, so the real system is never read or written.
set -uo pipefail
src=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
check() { # <name> <command...>: the command's exit status is the verdict
  local name=$1; shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
}
has()   { grep -qF -- "$1" <<<"${!2}"; }   # <needle> <name of variable holding the text>
hasnt() { ! has "$@"; }
is()    { [ "$1" = "$2" ]; }

# --- fixtures ---------------------------------------------------------------
om=$tmp/omarchy repo=$tmp/repo cfg=$tmp/cfg marker=$tmp/state/dotfiles/omarchy-changed
export OMARCHY_PATH=$om XDG_CONFIG_HOME=$cfg XDG_STATE_HOME=$tmp/state PATH=$tmp/bin:$PATH
mkdir -p "$tmp/bin" "$om/default/hypr/bindings" "$om/default/omarchy" "$om/config/omarchy" "$om/migrations" \
         "$repo/upstream" "$repo/features/t" "$cfg/omarchy"
printf '#!/bin/bash\ncat %q\n' "$tmp/version" > "$tmp/bin/omarchy-version"; chmod +x "$tmp/bin/omarchy-version"
echo 4.5.0-3 > "$tmp/version"
cp "$src/omarchy-diff" "$src/omarchy-review" "$repo/"
cat > "$repo/upstream/watch" <<'W'
default/hypr/bindings/*.lua
default/hypr/input.lua
default/hypr/looknfeel.lua
default/hypr/windows.lua
config/omarchy/shell.json
default/omarchy/omarchy-menu.jsonc
W
: > "$repo/features/t/upstream"
cat > "$repo/features/t/hypr.lua" <<'L'
o.bind("SUPER + ALT + SHIFT + B", "Mine", "true")
o.bind("SUPER + ALT + O", "Mine too", "true")
hl.config({ input = { touchpad = { natural_scroll = true } } })
hl.config({
  misc = { focus_on_activate = false },
})
L
cat > "$om/default/hypr/bindings/tiling.lua" <<'L'
o.bind("SUPER + SHIFT + ALT + B", "Stock thing", "true")
o.bind("SUPER + RETURN", "Terminal", "true")
L
printf 'hl.config({ input = { touchpad = { natural_scroll = false } } })\n' > "$om/default/hypr/input.lua"
printf 'hl.config({ misc = { focus_on_activate = true } })\n' > "$om/default/hypr/looknfeel.lua"
printf -- '-- windows\n' > "$om/default/hypr/windows.lua"
printf '{}\n' > "$om/default/omarchy/omarchy-menu.jsonc"
echo '{"bar":{"background":"opaque","layout":{"center":[{"id":"omarchy.clock","format":"dddd HH:mm"}]}},"dock":{"position":"bottom"}}' > "$om/config/omarchy/shell.json"
echo '{"bar":{"background":"none","layout":{"center":[{"id":"omarchy.clock","format":"ddd d MMM HH:mm"}],"right":[{"id":"omarchy.tray","pinned":["a","b"]}]}}}' > "$cfg/omarchy/shell.json"
printf 'echo "First migration"\n' > "$om/migrations/100.sh"
printf 'echo "Second migration"\n' > "$om/migrations/200.sh"

review() { (cd "$repo" && ./omarchy-review "$@" 2>&1); }
vline() { sed -n "${1}p" "$repo/upstream/VERSION"; }

# --- 1. first run records the baselines and the version, nothing is due -----
out=$(review); rc=$?
check "first run exits 0"                 is "$rc" 0
check "VERSION records version"           is "$(vline 1)" 4.5.0-3
check "VERSION records newest migration"  is "$(vline 2)" 200
check "watched baselines recorded"        test -f "$repo/upstream/default/hypr/input.lua" -a -f "$repo/upstream/config/omarchy/shell.json"
check "glob in watch expands"             test -f "$repo/upstream/default/hypr/bindings/tiling.lua"
check "no migrations listed on first run" hasnt "First migration" out
out=$(review --check); rc=$?
check "check: nothing due"                is "$rc" 0
check "check: no marker"                  test ! -e "$marker"

# --- 2. a key I bind that stock also binds, regardless of modifier order ----
out=$(review)
check "collision reported with stock description" has 'Stock thing' out
check "collision names my key"                   has 'SUPER + ALT + SHIFT + B' out
check "collision names my feature"               has 'features/t/hypr.lua' out
check "non-colliding key not reported"           hasnt 'SUPER + ALT + O' out

# --- 3. my bar keys versus stock, flagged only when stock moved -------------
check "differing bar key listed"                 has 'bar.background' out
check "differing bar key shows both values"      has '"none"' out
check "key absent from mine listed"              has 'dock.position' out
check "unchanged stock value not flagged"        hasnt 'stock changed' out

# --- 4. stock changes a watched file that I pin an option in ---------------
printf 'hl.config({ input = { touchpad = { natural_scroll = true } } })\n' > "$om/default/hypr/input.lua"
out=$(review --check); rc=$?
check "check: watched change is due"             is "$rc" 1
check "check: marker set"                        test -e "$marker"
out=$(review)
pinned=$(grep -i 'pin' <<<"$out")
check "watched diff shown"                       has '== default/hypr/input.lua' out
check "watched diff has the hunk"                has '+hl.config({ input = { touchpad = { natural_scroll = true } } })' out
check "pinned option flagged"                    has 'natural_scroll' pinned
check "unrelated pinned option not flagged"      hasnt 'focus_on_activate' pinned
check "marker cleared after review"              test ! -e "$marker"
out=$(review)
check "baseline advanced: second run quiet"      hasnt '== default/hypr/input.lua' out

# --- 5. version bump: migrations since the marker, release link ------------
echo 4.6.0-1 > "$tmp/version"
printf 'echo "Third migration"\n' > "$om/migrations/300.sh"
jq '.bar.background = "glass"' "$om/config/omarchy/shell.json" > "$tmp/sj" && mv "$tmp/sj" "$om/config/omarchy/shell.json"
out=$(review --check); rc=$?
check "check: version bump is due"               is "$rc" 1
check "check: says the range"                    has '4.5.0-3 -> 4.6.0-1' out
out=$(review)
bgline=$(grep 'bar.background' <<<"$out")
check "review: range"                            has '4.5.0-3 -> 4.6.0-1' out
check "review: releases link"                    has 'github.com/omacom/omarchy/releases' out
check "review: new migration listed"             has 'Third migration' out
check "review: old migrations not listed"        hasnt 'Second migration' out
check "review: bar key flagged when stock moved" has 'stock changed' bgline
check "VERSION advanced"                         is "$(vline 1):$(vline 2)" 4.6.0-1:300
out=$(review --check); rc=$?
check "check: quiet after review"                is "$rc" 0

exit $fail
