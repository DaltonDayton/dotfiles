#!/usr/bin/env bash
# Symlink this repo's files into place. Idempotent: rerun any time.
#   ./install.sh          link everything
#   ./install.sh --dry    show what would change
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
[[ "${1:-}" == "--dry" ]] && DRY=1

# Linked as a whole directory rather than file-by-file, because something else
# writes into them (lazy.nvim's lock file, new plugin files) and those writes
# should land in the repo.
LINK_DIRS=(
  config/nvim
  home/.claude/rules
  home/.claude/stacks
)

# Tracked for reference but not linked.
SKIP=(
  home/.zshrc          # currently on bash under Omarchy; link this if you switch back to zsh
  config/git/personal  # pulled in by an [include] instead; see git_include() below
)

target_for() { # repo-relative path -> absolute destination
  case "$1" in
    config/*) echo "$HOME/.config/${1#config/}" ;;
    home/*)   echo "$HOME/${1#home/}" ;;
  esac
}

link() {
  local rel="$1" src="$REPO/$1" dst
  dst="$(target_for "$rel")"

  if [[ "$(readlink -- "$dst" 2>/dev/null)" == "$src" ]]; then
    return 0                                    # already correct
  fi
  if (( DRY )); then
    printf '  would link %s\n' "$rel"; return 0
  fi

  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then       # real file in the way: keep a copy
    mv -- "$dst" "$dst.bak.$(date +%s)"
    printf '  backed up %s\n' "$dst"
  fi
  ln -sfn -- "$src" "$dst"
  printf '  linked    %s\n' "$rel"
}

skipped() {
  local rel="$1"
  for s in "${SKIP[@]}"; do [[ "$rel" == "$s" ]] && return 0; done
  return 1
}

under_link_dir() {
  local rel="$1"
  for d in "${LINK_DIRS[@]}"; do [[ "$rel" == "$d"/* ]] && return 0; done
  return 1
}

# git has no drop-in config directory, and ~/.gitconfig shadows
# ~/.config/git/config rather than layering over it. So instead of replacing
# Omarchy's file, point it at ours and let upstream keep owning the rest.
git_include() {
  local cfg="$HOME/.config/git/config" line="	path = $REPO/config/git/personal"
  grep -qxF "$line" "$cfg" 2>/dev/null && return 0
  if (( DRY )); then printf '  would add [include] -> config/git/personal in %s\n' "$cfg"; return 0; fi
  mkdir -p "$(dirname "$cfg")"
  printf '\n[include]\n%s\n' "$line" >> "$cfg"
  printf '  included  config/git/personal in %s\n' "$cfg"
}

cd "$REPO"
git_include
for d in "${LINK_DIRS[@]}"; do
  [[ -d "$d" ]] && link "$d"
done

while IFS= read -r rel; do
  skipped "$rel" && continue
  under_link_dir "$rel" && continue
  link "$rel"
done < <(find config home -type f -not -name '.gitkeep' | sed 's|^\./||' | sort)

echo "done."
