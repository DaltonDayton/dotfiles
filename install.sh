#!/usr/bin/env bash
# Symlink this repo's files into place. Idempotent: rerun any time.
#   ./install.sh                     link everything not marked PENDING
#   ./install.sh --dry               show what would change
#   ./install.sh --machine=laptop    also pick which monitors.<machine>.lua to use
#
# The machine choice is remembered in ~/.local/state/omarchy-dotfiles/machine,
# so you only pass --machine once per box. Add a new machine by dropping in a
# config/hypr/monitors.<name>.lua; it shows up as a choice automatically.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
MACHINE=""
MACHINE_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-dotfiles/machine"

for arg in "$@"; do
  case "$arg" in
    --dry)         DRY=1 ;;
    --machine=*)   MACHINE="${arg#--machine=}" ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

machines() { # available machine names, from the monitors files
  local f
  for f in "$REPO"/config/hypr/monitors.*.lua; do
    [[ -e "$f" ]] || continue
    f="${f##*/monitors.}"; echo "${f%.lua}"
  done
}

# Precedence: --machine flag > remembered choice. No guessing from hostname --
# a wrong monitors.lua is disruptive enough to be worth stating once explicitly.
if [[ -z "$MACHINE" && -r "$MACHINE_STATE" ]]; then
  MACHINE="$(<"$MACHINE_STATE")"
fi

if [[ -z "$MACHINE" ]]; then
  echo "No machine selected. Rerun with one of:" >&2
  while IFS= read -r m; do echo "  ./install.sh --machine=$m" >&2; done < <(machines)
  exit 1
fi

if ! machines | grep -qxF "$MACHINE"; then
  echo "Unknown machine '$MACHINE'. Available:" >&2
  while IFS= read -r m; do echo "  $m" >&2; done < <(machines)
  exit 1
fi

# Carried over from the pre-Omarchy setup but NOT adopted yet. Still in the repo
# so it's there to pick from; just not linked. To adopt one, delete its line
# here and rerun. To see what you'd be taking on first:
#   diff /usr/share/omarchy/config/<path> <repo path>
PENDING=(
  home/.zshrc                  # on bash under Omarchy; needs a chsh to matter
  home/.claude/CLAUDE.md
  home/.claude/rules
  home/.claude/stacks
  config/tmux/tmux.conf        # would replace Omarchy's default tmux config
  config/sesh/sesh.toml
  config/opencode/opencode.json
  config/opencode/tui.json
  config/git/personal          # applied via [include], not a symlink
)

# Linked as a whole directory rather than file-by-file, because something else
# writes into them (lazy.nvim's lock file, new plugin files) and those writes
# should land in the repo.
LINK_DIRS=(
  config/nvim
  home/.claude/rules
  home/.claude/stacks
)

pending() { local p="$1"; for x in "${PENDING[@]}"; do [[ "$p" == "$x" ]] && return 0; done; return 1; }
# monitors.<machine>.lua is linked by link_monitors, not the generic sweep.
per_machine() { [[ "$1" == config/hypr/monitors.*.lua ]]; }
under_link_dir() { local p="$1"; for d in "${LINK_DIRS[@]}"; do [[ "$p" == "$d"/* ]] && return 0; done; return 1; }

target_for() { # repo-relative path -> absolute destination
  case "$1" in
    config/*) echo "$HOME/.config/${1#config/}" ;;
    home/*)   echo "$HOME/${1#home/}" ;;
  esac
}

link() {
  local rel="$1" src="$REPO/$1" dst
  dst="$(target_for "$rel")"

  [[ "$(readlink -- "$dst" 2>/dev/null)" == "$src" ]] && return 0   # already correct
  if (( DRY )); then printf '  would link %s\n' "$rel"; return 0; fi

  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then       # real file in the way: keep a copy
    mv -- "$dst" "$dst.bak.$(date +%s)"
    printf '  backed up %s\n' "$dst"
  fi
  ln -sfn -- "$src" "$dst"
  printf '  linked    %s\n' "$rel"
}

# git has no drop-in config directory, and ~/.gitconfig shadows
# ~/.config/git/config rather than layering over it. So instead of replacing
# Omarchy's file, point it at ours and let upstream keep owning the rest.
git_include() {
  pending config/git/personal && return 0
  local cfg="$HOME/.config/git/config" line="	path = $REPO/config/git/personal"
  grep -qxF "$line" "$cfg" 2>/dev/null && return 0
  if (( DRY )); then printf '  would add [include] -> config/git/personal in %s\n' "$cfg"; return 0; fi
  mkdir -p "$(dirname "$cfg")"
  printf '\n[include]\n%s\n' "$line" >> "$cfg"
  printf '  included  config/git/personal\n'
}

# The one file whose content is machine-specific. Everything else is shared.
link_monitors() {
  local src="$REPO/config/hypr/monitors.$MACHINE.lua" dst="$HOME/.config/hypr/monitors.lua"

  if [[ "$(readlink -- "$dst" 2>/dev/null)" != "$src" ]]; then
    if (( DRY )); then
      printf '  would link config/hypr/monitors.%s.lua -> %s\n' "$MACHINE" "$dst"
    else
      mkdir -p "$(dirname "$dst")"
      if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv -- "$dst" "$dst.bak.$(date +%s)"
        printf '  backed up %s\n' "$dst"
      fi
      ln -sfn -- "$src" "$dst"
      printf '  linked    config/hypr/monitors.%s.lua\n' "$MACHINE"
    fi
  fi

  if (( ! DRY )); then
    mkdir -p "$(dirname "$MACHINE_STATE")"
    printf '%s\n' "$MACHINE" > "$MACHINE_STATE"
  fi
}

cd "$REPO"
echo "machine: $MACHINE"
git_include
link_monitors
for d in "${LINK_DIRS[@]}"; do
  pending "$d" && continue
  [[ -d "$d" ]] && link "$d"
done

while IFS= read -r rel; do
  pending "$rel" && continue
  under_link_dir "$rel" && continue
  per_machine "$rel" && continue
  link "$rel"
done < <(find config home -type f -not -name '.gitkeep' | sort)

echo "done."
