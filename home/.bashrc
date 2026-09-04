# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# Listings: keep Omarchy's `ls`, rename its `lsa` to `ll`, add `cll`.
unalias lsa 2>/dev/null
alias ll='ls -a'
alias cll='clear && ll'

# uv (Astral installer) prepends ~/.local/bin so its binaries beat /usr/bin.
# Omarchy only appends it, so without this a pacman-installed uv would win.
# Guarded: harmless on a machine where uv was never installed this way.
[[ -r "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# Git history as a graph, one line per commit. Ported from the old .zshrc.
alias githist="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --date=short --date-order"
alias githistall="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --all --date=short --date-order"
alias lg='lazygit'

# sdev: pick a zoxide dir, open (or switch to) a tmux session there with
# ai / nvim / term windows. Everything it needs ships with Omarchy.
sdev() {
  local dir name
  dir=$(zoxide query -l | fzf \
    --no-sort --ansi --border-label ' sdev ' --prompt '🛠  ' \
    --preview 'eza --all --git --icons --color=always {}' \
    --preview-window 'right:55%')
  [[ -z "$dir" ]] && return

  name=$(basename "$dir" | tr -c 'A-Za-z0-9_-' '-' | sed 's/--*/-/g; s/^-//; s/-$//')

  if ! tmux has-session -t="$name" 2>/dev/null; then
    tmux new-session   -d -s "$name" -c "$dir" -n "ai"
    tmux new-window    -t "$name:"   -c "$dir" -n "nvim" "nvim .; exec \$SHELL"
    tmux new-window    -t "$name:"   -c "$dir" -n "term"
    tmux select-window -t "$name:ai"
  fi

  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach -t "$name"
  fi
}

# s: sesh session picker. sesh isn't an Omarchy package and isn't installed
# yet (config/sesh/sesh.toml is staged for when it is), so this is defined
# only once it's on PATH.
if command -v sesh >/dev/null; then
  s() {
    local session
    session=$(sesh list --icons | fzf \
      --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
      --header '  ^a all ^t tmux ^g configs ^x zoxide ^f find' \
      --bind 'tab:down,btab:up' \
      --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
      --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
      --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
      --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
      --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d . ~)' \
      --preview-window 'right:55%' \
      --preview 'sesh preview {}')
    [[ -n "$session" ]] && sesh connect "$session"
  }
fi
