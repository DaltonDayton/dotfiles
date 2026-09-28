# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
source "$OMARCHY_PATH/default/bash/rc"

unalias lsa 2>/dev/null
alias ll='ls -a'
alias cll='clear && ll'
alias lg='lazygit'
alias githist="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --date=short --date-order"
alias githistall="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --all --date=short --date-order"

# uv's installer puts ~/.local/bin first so its binaries beat /usr/bin.
[[ -r "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# sdev: pick a zoxide dir, open (or switch to) a tmux session there with
# ai / nvim / term windows.
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
