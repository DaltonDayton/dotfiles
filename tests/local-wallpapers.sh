#!/usr/bin/env bash
# Behavior of features/local-wallpapers/files/.local/bin/omarchy-bg-local against a
# throwaway HOME. omarchy-menu-images and omarchy-theme-bg-set are stubbed on PATH and
# record their arguments, so no picker opens and nothing is set for real.
set -uo pipefail
src=$(cd "$(dirname "$0")/.." && pwd)
script=$src/features/local-wallpapers/files/.local/bin/omarchy-bg-local
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
check() { # <name> <command...>
  local name=$1; shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
}
has()   { grep -qF -- "$1" <<<"${!2}"; }
hasnt() { ! has "$@"; }
is()    { [ "$1" = "$2" ]; }

export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/home/.config XDG_STATE_HOME=$tmp/home/.local/state XDG_CACHE_HOME=$tmp/home/.cache
export PATH=$tmp/bin:$PATH STUB_LOG=$tmp/stub.log
mkdir -p "$tmp/bin" "$XDG_CONFIG_HOME/omarchy/backgrounds/.local" "$XDG_STATE_HOME/omarchy/current" "$tmp/theme/backgrounds/extra"
printf '#!/bin/bash\necho "menu-images $*" >> "$STUB_LOG"\necho "$STUB_PICK"\n' > "$tmp/bin/omarchy-menu-images"
printf '#!/bin/bash\necho "bg-set $*" >> "$STUB_LOG"\n' > "$tmp/bin/omarchy-theme-bg-set"
chmod +x "$tmp/bin"/*
local=$XDG_CONFIG_HOME/omarchy/backgrounds/.local
for f in a b c d; do echo "$f" > "$local/$f.jpg"; done
cat > "$local/manifest" <<'M'
# filename: theme [theme ...]  (empty = reachable only with --all)
a.jpg: kanagawa noir
b.jpg: noir
c.jpg:
M
# d.jpg is in the folder but not in the manifest at all
echo "theme-own" > "$tmp/theme/backgrounds/extra/own.jpg"
echo "visible" > "$tmp/theme/backgrounds/vis.jpg"
ln -s "$tmp/theme" "$XDG_STATE_HOME/omarchy/current/theme"
echo kanagawa > "$XDG_STATE_HOME/omarchy/current/theme.name"
ln -s "$tmp/theme/backgrounds/vis.jpg" "$XDG_STATE_HOME/omarchy/current/background"
export STUB_PICK=""

# --- per-theme view ---------------------------------------------------------
out=$("$script" --print 2>&1); rc=$?
check "print exits 0"                     is "$rc" 0
check "tagged for theme listed"           has "a.jpg" out
check "theme's own extra listed"         has "own.jpg" out
check "tagged for other theme not listed" hasnt "b.jpg" out
check "untagged not listed"               hasnt "c.jpg" out
check "unmanifested not listed"           hasnt "d.jpg" out
check "visible background not listed"     hasnt "vis.jpg" out
view=$XDG_CACHE_HOME/omarchy/local-wallpapers/kanagawa
check "view is a stable dir of symlinks"  test -L "$view/a.jpg" -a -L "$view/own.jpg"
check "symlink resolves to the real file" is "$(readlink -f "$view/a.jpg")" "$local/a.jpg"

# --- --all view -------------------------------------------------------------
out=$("$script" --all --print 2>&1)
for f in a b c d; do check "all: $f.jpg listed" has "$f.jpg" out; done
check "all: theme's own extra listed too" has "own.jpg" out
check "all: separate view dir"             test -L "$XDG_CACHE_HOME/omarchy/local-wallpapers/all/c.jpg"

# --- picking ----------------------------------------------------------------
: > "$STUB_LOG"
STUB_PICK="$view/a.jpg" "$script"; rc=$?
log=$(<"$STUB_LOG")
check "pick: exits 0"                        is "$rc" 0
check "pick: picker opened on the view"      has "menu-images --selected $tmp/theme/backgrounds/vis.jpg $view" log
check "pick: chosen file set as background"  has "bg-set $local/a.jpg" log
: > "$STUB_LOG"
STUB_PICK="" "$script"; rc=$?
log=$(<"$STUB_LOG")
check "cancel: exits 0"                      is "$rc" 0
check "cancel: nothing set"                  hasnt "bg-set" log

# --- stale symlink dropped on rebuild ----------------------------------------
rm "$local/a.jpg"
out=$("$script" --print 2>&1)
check "removed wallpaper leaves the view"    hasnt "a.jpg" out

# --- empty result -----------------------------------------------------------
echo plain > "$XDG_STATE_HOME/omarchy/current/theme.name"
rm "$tmp/theme/backgrounds/extra/own.jpg"
: > "$STUB_LOG"
out=$("$script" 2>&1); rc=$?
log=$(<"$STUB_LOG")
check "nothing for theme: says so, exit 0"   is "$rc" 0
check "nothing for theme: no picker"         hasnt "menu-images" log
check "nothing for theme: message"           has "No local backgrounds" out
out=$("$script" --print 2>&1)
check "nothing for theme: print is empty"    is "$out" ""

exit $fail
