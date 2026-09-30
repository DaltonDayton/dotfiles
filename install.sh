#!/usr/bin/env bash
# Apply a profile: for each feature it lists, install packages, link files, and
# run its setup; undo features that were dropped from the list. Safe to rerun,
# and silent when there's nothing to change.
#   ./install.sh                  apply the current profile (asks for one the first time)
#   ./install.sh --profile NAME   switch to profiles/NAME, then apply
#   ./install.sh --pick           pick the profile's features from a checklist, then apply
#
# Dropping a feature runs its `off`, removes its links (restoring any file they
# replaced), and removes the packages install.sh installed for it.
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
LOG=$STATE/install.log
mkdir -p "$STATE"
touch "$STATE/links" "$STATE/packages"

# ------------------------------------------------------------------ output

HEADER_DONE=0
say() { # print and log a change; the log gets a header once per run
  if (( ! HEADER_DONE )); then
    HEADER_DONE=1
    printf '\n== %s  profile=%s\n' "$(date '+%F %T')" "$PROFILE" >> "$LOG"
  fi
  echo "$*"
  echo "$*" >> "$LOG"
}
run() { say "run: $*"; "$@"; }
die() { echo "error: $*" >&2; exit 1; }

# ------------------------------------------------------ helpers for setup/off

ensure_line() { # <file> <line>
  grep -qxF -- "$2" "$1" 2>/dev/null && return 0
  printf '\n%s\n' "$2" >> "$1"
  say "added to $1: $2"
}
remove_line() { # <file> <line>
  grep -qxF -- "$2" "$1" 2>/dev/null || return 0
  local tmp; tmp=$(mktemp)
  grep -vxF -- "$2" "$1" > "$tmp" || true
  cat "$tmp" > "$1" && rm "$tmp"
  say "removed from $1: $2"
}
ensure_block() { # <file> <header> <line>: e.g. a git [include] section
  grep -qxF -- "$3" "$1" 2>/dev/null && return 0
  printf '\n%s\n%s\n' "$2" "$3" >> "$1"
  say "added to $1: $2 $3"
}
remove_block() { # <file> <header> <line>: drops the line and the header just above it
  grep -qxF -- "$3" "$1" 2>/dev/null || return 0
  local tmp; tmp=$(mktemp)
  awk -v h="$2" -v l="$3" '
    { lines[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (lines[i] == h && lines[i + 1] == l) { i++; continue }
        print lines[i]
      }
    }' "$1" > "$tmp"
  cat "$tmp" > "$1" && rm "$tmp"
  say "removed from $1: $2 $3"
}

SHELL_JSON=$HOME/.config/omarchy/shell.json
bar_value() { # <id> <key>: current value as compact JSON, or null
  jq -c --arg id "$1" --arg key "$2" \
    'first(.bar.layout[]?[]? | objects | select(.id == $id) | .[$key]) // null' "$SHELL_JSON"
}
bar_set() { # <id> <key> <value> [--json]: only when it differs
  local want
  if [[ ${4:-} == --json ]]; then want=$(jq -c . <<<"$3"); else want=$(jq -cn --arg v "$3" '$v'); fi
  [[ $(bar_value "$1" "$2") == "$want" ]] && return 0
  say "run: omarchy bar set $*"; omarchy bar set "$@" >/dev/null
}

# --------------------------------------------------------------- arguments

PROFILE=""
[[ -r $STATE/profile ]] && PROFILE=$(<"$STATE/profile")
PICK=0
while (( $# )); do
  case $1 in
    --profile) PROFILE=${2:?--profile needs a name}; shift ;;
    --profile=*) PROFILE=${1#*=} ;;
    --pick) PICK=1 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

if [[ -z $PROFILE ]]; then
  PROFILE=$(find "$REPO/profiles" -type f -printf '%f\n' | sort | gum choose --header "Profile for this machine")
fi
PROFILE_FILE=$REPO/profiles/$PROFILE
[[ -f $PROFILE_FILE ]] || die "no profile '$PROFILE' in profiles/"
[[ $(cat "$STATE/profile" 2>/dev/null) == "$PROFILE" ]] || { echo "$PROFILE" > "$STATE/profile"; say "profile set to $PROFILE"; }

listed() { { grep -v '^[[:space:]]*#' "$PROFILE_FILE" || true; } | awk NF | sort -u; }

if (( PICK )); then
  mapfile -t current < <(listed)
  items=() selected=()
  for d in "$REPO"/features/*/; do
    n=$(basename "$d")
    items+=("$(printf '%-24s %s' "$n" "$(cat "$d/about" 2>/dev/null)")")
    printf '%s\n' "${current[@]}" | grep -qxF "$n" && selected+=("${items[-1]}")
  done
  chosen=$(IFS=,; gum choose --no-limit --height 40 --header "Features for $PROFILE (space to toggle)" \
    --selected="${selected[*]}" "${items[@]}") || die "cancelled"
  awk '{print $1}' <<<"$chosen" > "$PROFILE_FILE"
  say "profiles/$PROFILE now lists: $(listed | tr '\n' ' ')"
fi

# ---------------------------------------------------------------- features

mapfile -t WANT < <(listed)
for f in "${WANT[@]}"; do [[ -d $REPO/features/$f ]] || die "profiles/$PROFILE lists '$f', but features/$f doesn't exist"; done

targets() { # <feature>: "src<TAB>dst" for everything it links
  local d=$REPO/features/$1 rel skip
  [[ -f $d/hypr.lua ]] && printf '%s\t%s\n' "$d/hypr.lua" "$HOME/.config/hypr/features/$1.lua"
  [[ -d $d/files ]] || return 0
  local -a dirs=()
  [[ -f $d/linkdirs ]] && mapfile -t dirs < "$d/linkdirs"
  for rel in "${dirs[@]}"; do printf '%s\t%s\n' "$d/files/$rel" "$HOME/$rel"; done
  while IFS= read -r rel; do
    skip=0
    for dir in "${dirs[@]}"; do [[ $rel == "$dir"/* ]] && skip=1; done
    (( skip )) || printf '%s\t%s\n' "$d/files/$rel" "$HOME/$rel"
  done < <(find "$d/files" -type f -printf '%P\n' | sort)
}

# Two features linking the same path (e.g. both night lights) can't both be on.
dupes=$(for f in "${WANT[@]}"; do targets "$f" | cut -f2 | sed "s|^|$f\t|"; done | sort -t$'\t' -k2 | awk -F'\t' '
  $2 == prev { print "  " pf " and " $1 " both link " $2 } { prev = $2; pf = $1 }')
[[ -z $dupes ]] || die "conflicting features:"$'\n'"$dupes"

was_linked() { cut -f2 "$STATE/links" | grep -qxF -- "$1"; }

link() { # <feature> <src> <dst>
  local src=$2 dst=$3
  [[ $(readlink -- "$dst") == "$src" ]] && return 1
  mkdir -p "$(dirname "$dst")"
  if [[ -e $dst && ! -L $dst ]]; then
    local ts; ts=$(date +%s)
    if was_linked "$dst"; then
      # Something (e.g. Omarchy's monitor scaling, which uses sed -i) replaced our link.
      mv -- "$dst" "$dst.drift.$ts"
      say "warning: $dst had been replaced by a real file; kept it as $dst.drift.$ts"
      say "         compare: diff $src $dst.drift.$ts"
    else
      mv -- "$dst" "$dst.bak.$ts"
      say "backed up $dst -> $dst.bak.$ts"
    fi
  fi
  ln -sfn -- "$src" "$dst"
  say "linked    $dst"
}

unlink_entries() { # stdin: "feature<TAB>dst" lines. Remove our links, restoring the newest backup.
  local f dst bak
  while IFS=$'\t' read -r f dst; do
    [[ -L $dst && $(readlink -- "$dst") == "$REPO/features/$f/"* ]] || continue
    rm -- "$dst"
    [[ $dst == "$HOME/.config/hypr/"* ]] && HYPR_CHANGED=1
    bak=$(compgen -G "$dst.bak.*" | sort | tail -1 || true)
    if [[ -n $bak ]]; then mv -- "$bak" "$dst"; say "unlinked  $dst (restored $bak)"; else say "unlinked  $dst"; fi
  done
}
unlink_feature() { unlink_entries < <(awk -F'\t' -v f="$1" '$1 == f' "$STATE/links"); }

needed_by() { # <package>: an enabled feature that lists it, if any
  local g
  for g in "${WANT[@]}"; do
    grep -qxF -- "$1" "$REPO/features/$g/packages" "$REPO/features/$g/aur" 2>/dev/null && { echo "$g"; return 0; }
  done
  return 0
}

drop_packages() { # <feature>: remove the packages install.sh installed for it
  local f=$1 p owner tmp drop=()
  mapfile -t mine < <(awk -F'\t' -v f="$f" '$1 == f { print $2 }' "$STATE/packages" | sort -u)
  (( ${#mine[@]} )) || return 0
  tmp=$(mktemp)
  awk -F'\t' -v f="$f" '$1 != f' "$STATE/packages" > "$tmp"
  for p in "${mine[@]}"; do
    owner=$(needed_by "$p")
    if [[ -n $owner ]]; then
      printf '%s\t%s\n' "$owner" "$p" >> "$tmp"
      say "kept $p (still needed by $owner)"
    else
      drop+=("$p")
      # makepkg's default OPTIONS include debug, so AUR builds bring a -debug package along.
      if pacman -Q "$p-debug" &>/dev/null; then drop+=("$p-debug"); fi
    fi
  done
  mv "$tmp" "$STATE/packages"
  (( ${#drop[@]} )) || return 0
  run omarchy pkg drop "${drop[@]}" && return 0
  say "warning: could not remove ${drop[*]} (something else may depend on them)"
  for p in "${drop[@]}"; do   # keep tracking whatever is still installed
    pacman -Q "$p" &>/dev/null && printf '%s\t%s\n' "$f" "$p" >> "$STATE/packages"
  done
  return 0
}

run_script() { # <feature> <setup|off> <changed>
  local s=$REPO/features/$1/$2
  [[ -f $s ]] || return 0
  # Not `( … ) || die`: bash ignores set -e inside anything on the left of ||,
  # so a failing command in the script would go unnoticed.
  local rc
  set +e
  # The trailing `:` keeps a final `[[ … ]] && cmd` from counting as a failure.
  ( set -e; FEATURE=$REPO/features/$1 CHANGED=$3; eval "$(<"$s")"$'\n:' )
  rc=$?
  set -e
  (( rc == 0 )) || die "$1/$2 failed (exit $rc)"
}

HYPR_CHANGED=0

# 1. Hyprland loader: one line appended to Omarchy's hyprland.lua. Not
#    require_all, because its find skips symlinks and every feature file is one.
LOADER='for f in io.popen("find -L \"$HOME/.config/hypr/features\" -maxdepth 1 -name \"*.lua\" -printf \"%f\\n\" 2>/dev/null | sort"):lines() do require("hypr.features." .. f:gsub("%.lua$", "")) end -- dotfiles'
if [[ -f ~/.config/hypr/hyprland.lua ]] && ! grep -qxF -- "$LOADER" ~/.config/hypr/hyprland.lua; then
  ensure_line ~/.config/hypr/hyprland.lua "$LOADER"
  HYPR_CHANGED=1
fi

# 2. Features dropped from the profile.
APPLIED=()
[[ -r $STATE/applied ]] && mapfile -t APPLIED < "$STATE/applied"
for f in "${APPLIED[@]}"; do
  printf '%s\n' "${WANT[@]}" | grep -qxF "$f" && continue
  say "-- off: $f"
  run_script "$f" off 1
  [[ -f $REPO/features/$f/hypr.lua ]] && HYPR_CHANGED=1
  unlink_feature "$f"
  drop_packages "$f"
done

# 3. Features in the profile.
NEW_LINKS=$(mktemp)
for f in "${WANT[@]}"; do
  d=$REPO/features/$f
  missing=()
  for list in packages aur; do
    [[ -f $d/$list ]] || continue
    want=()
    while read -r p; do [[ -n $p ]] && ! pacman -Q "$p" &>/dev/null && want+=("$p"); done < "$d/$list"
    (( ${#want[@]} )) || continue
    if [[ $list == aur ]]; then run omarchy pkg aur add "${want[@]}"; else run omarchy pkg add "${want[@]}"; fi
    # Only what install.sh installed gets removed again when the feature is dropped.
    printf "$f\t%s\n" "${want[@]}" >> "$STATE/packages"
  done

  changed=0
  while IFS=$'\t' read -r src dst; do
    printf '%s\t%s\n' "$f" "$dst" >> "$NEW_LINKS"
    if link "$f" "$src" "$dst"; then
      changed=1
      [[ $dst == "$HOME/.config/hypr/"* ]] && HYPR_CHANGED=1
    fi
  done < <(targets "$f")

  run_script "$f" setup "$changed"
done

# Links a still-enabled feature no longer ships (e.g. a deleted hypr.lua).
unlink_entries < <(sort "$STATE/links" | comm -23 - <(sort "$NEW_LINKS"))

printf '%s\n' "${WANT[@]}" | awk NF > "$STATE/applied"
mv "$NEW_LINKS" "$STATE/links"

# 4. Validate Hyprland once if anything it reads changed.
if (( HYPR_CHANGED )) && command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null
  errors=$(hyprctl configerrors)
  if [[ -n $errors && $errors != "no errors" ]]; then say "hyprland config errors:"; say "$errors"; else say "hyprland reloaded, no config errors"; fi
fi
