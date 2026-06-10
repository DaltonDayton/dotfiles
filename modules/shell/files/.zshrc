export PATH="$HOME/.asdf/shims:$PATH"
export PATH="$HOME/.asdf/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Suppress zoxide doctor check (false positive in Claude Code shell snapshot,
# which reorders init so zoxide is not last even though ~/.zshrc has it last).
export _ZO_DOCTOR=0

# ZINIT
# =====
# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"
# zinit plugins
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-syntax-highlighting

# TODO: Look into moving starship to zinit?
# https://github.com/zdharma-continuum/zinit?tab=readme-ov-file#plugins-and-snippets


# Added by initial installer
# ==========================
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt notify
unsetopt beep
bindkey -v
# Fix special keys in vi mode
bindkey '^[[3~' delete-char           # Delete key
bindkey '^[[1;5D' backward-word       # Ctrl+Left
bindkey '^[[1;5C' forward-word        # Ctrl+Right
bindkey '^[[H' beginning-of-line      # Home
bindkey '^[[F' end-of-line            # End
bindkey '^[[1~' beginning-of-line     # Home (alternate)
bindkey '^[[4~' end-of-line           # End (alternate)
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/dalton/.zshrc'
autoload -Uz compinit
compinit
# End of lines added by compinstall

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
# zstyle ':fzf-tab:complete:cd:*' fzf-preview 'bat.exe {-l} --color=always'
# zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'bat.exe {-l} --color=always'


# Aliases
# =======
alias  c='clear' # clear terminal
alias  l='eza -lh  --icons=auto' # long list
alias ls='eza -1   --icons=auto' # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias cll='clear && ll' # clear and long list all
alias ld='eza -lhD --icons=auto' # long list dirs
alias lt='eza --icons=auto --tree' # list folder as tree
alias githist="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --date=short --date-order"
alias githistall="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --all --date=short --date-order"
alias ff="fzf --preview 'bat {-1} --color=always'"
alias sz="source ~/.zshrc"
alias lg='lazygit'

# Work around Crush terminal capability probe bleed (e.g. Gi=31;OK)
crush() {
    TERM_PROGRAM=Apple_Terminal command crush "$@"
}

# Handy change dir shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
# Always mkdir a path (this doesn't inhibit functionality to make a single dir)
alias mkdir='mkdir -p'


# Shell integrations
# ==================
eval "$(fzf --zsh)"
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v atuin    >/dev/null && eval "$(atuin init zsh)"
# eval "$(tv init zsh)"
command -v uv >/dev/null && eval "$(uv generate-shell-completion zsh)"
command -v sesh >/dev/null && eval "$(sesh completion zsh)"

# sesh picker from any shell — creates/attaches tmux session at chosen target
function s() {
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

# sdev: pick a zoxide dir, open tmux session with 3 windows (ai, nvim, term)
function sdev() {
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














# export PATH="$HOME/.asdf/shims:$PATH"
# export PATH="$HOME/.asdf/bin:$PATH"
# export PATH="$HOME/.local/bin:$PATH"
# export PATH="$HOME/fzf/bin:$PATH"
# export PATH="/opt/cuda/bin:$PATH"
#
# export EDITOR=nvim
#
# # export LIBGL_ALWAYS_SOFTWARE=1 # Force software rendering for OpenGL (instead of GPU)
#
# # Set the directory we want to store zinit and plugins
# ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
#
# # Download Zinit, if it's not there yet
# if [ ! -d "$ZINIT_HOME" ]; then
#    mkdir -p "$(dirname $ZINIT_HOME)"
#    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
# fi
#
# # Source/Load zinit
# source "${ZINIT_HOME}/zinit.zsh"
#
# # Zinit Update Commands
# # zinit self-update
# # zinit update
#
# # hyde_plugins=(sudo git zsh-256color zsh-autosuggestions zsh-syntax-highlighting)
#
# # Add in zsh plugins
# zinit light zsh-users/zsh-syntax-highlighting
# zinit light zsh-users/zsh-completions
# zinit light zsh-users/zsh-autosuggestions
# zinit light Aloxaf/fzf-tab
#
# zinit ice depth=1
# zinit light jeffreytse/zsh-vi-mode
#
# # Add in snippets
# # zinit snippet OMZP::git
# zinit snippet OMZP::sudo
# zinit snippet OMZP::command-not-found
#
# # Load completions
# autoload -Uz compinit && compinit
#
# zinit cdreplay -q
#
# # Keybindings
# bindkey -e
# bindkey '^p' history-search-backward
# bindkey '^n' history-search-forward
# bindkey '^[w' kill-region
# # Home key
# bindkey '\e[1~' beginning-of-line
# bindkey '\e[H' beginning-of-line
# # End key
# bindkey '\e[4~' end-of-line
# bindkey '\e[F' end-of-line
# # Ctrl+Left Arrow key
# bindkey '^[[1;5D' backward-word
# # Ctrl+Right Arrow key
# bindkey '^[[1;5C' forward-word
#
# # History
# HISTSIZE=5000
# HISTFILE=~/.zsh_history
# SAVEHIST=$HISTSIZE
# HISTDUP=erase
# setopt appendhistory
# setopt sharehistory
# setopt hist_ignore_space
# setopt hist_ignore_all_dups
# setopt hist_save_no_dups
# setopt hist_ignore_dups
# setopt hist_find_no_dups
#
# # Completion styling
# zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
# zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
# zstyle ':completion:*' menu no
# zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
# zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
# # zstyle ':fzf-tab:complete:cd:*' fzf-preview 'bat.exe {-l} --color=always'
# # zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'bat.exe {-l} --color=always'
#
# # Aliases
# # alias  cd='z' # cd to zoxide
# alias  c='clear' # clear terminal
# alias  l='eza -lh  --icons=auto' # long list
# alias ls='eza -1   --icons=auto' # short list
# alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
# alias cll='clear && ll' # clear and long list all
# alias ld='eza -lhD --icons=auto' # long list dirs
# alias lt='eza --icons=auto --tree' # list folder as tree
# alias githist="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --date=short --date-order"
# alias githistall="git log --pretty='%C(yellow)%h %C(cyan)%cd %Cblue%aN%C(auto)%d %Creset%s' --graph --all --date=short --date-order"
# alias ff="fzf --preview 'batcat {-1} --color=always'"
# alias sz="source ~/.zshrc"
# alias poetryactivate='source "$(poetry env info --path)/bin/activate"'
# alias pa='poetryactivate && export PYTHONPATH=$(pwd)'
# alias pd='deactivate'
# alias lg='lazygit'
#
# # nvim appname function
# # Usage: nv [config_name] [args...]
# # Examples:
# #   nv .           -> opens default nvim in current dir
# #   nv test .      -> opens nvimtest config in current dir
# #   nv minimal foo -> opens nvimminimal config editing foo
# nv() {
#     # Check if first arg looks like a config name (not a flag, file, or path)
#     if [[ -n "$1" && ! "$1" =~ ^[-.+/] && ! -e "$1" ]]; then
#         local config_name="$1"
#         shift
#         NVIM_APPNAME="nvim${config_name}" nvim "$@"
#     else
#         nvim "$@"
#     fi
# }
#
# # Function to record screen with a specified filename
# record_screen() {
#     local filename=$1
#     if [ -z "$filename" ]; then
#         echo "Usage: record_screen <filename>"
#         return 1
#     fi
#     wf-recorder -f "${filename}.mp4"
# }
#
# # Function to convert the recording to GIF with a specified filename
# convert_to_gif() {
#     local filename=$1
#     if [ -z "$filename" ]; then
#         echo "Usage: convert_to_gif <filename>"
#         return 1
#     fi
#     ffmpeg -i "${filename}.mp4" -vf "fps=15,scale=640:-1:flags=lanczos" -c:v gif "${filename}.gif"
# }
#
# record_and_convert() {
#     local filename=$1
#     if [ -z "$filename" ]; then
#         echo "Usage: record_and_convert <filename>"
#         return 1
#     fi
#
#     # Start recording
#     wf-recorder -f "${filename}.mp4"
#
#     # Wait for the recording to finish
#     echo "Recording stopped. Converting to GIF..."
#
#     # Convert to GIF with 15fps
#     ffmpeg -i "${filename}.mp4" -vf "fps=15,scale=640:-1:flags=lanczos" -c:v gif "${filename}.gif"
#
#     echo "Conversion complete: ${filename}.gif"
# }
#
# # Handy change dir shortcuts
# alias ..='cd ..'
# alias ...='cd ../..'
# alias .3='cd ../../..'
# alias .4='cd ../../../..'
# alias .5='cd ../../../../..'
#
# # Always mkdir a path (this doesn't inhibit functionality to make a single dir)
# alias mkdir='mkdir -p'
#
# showPreview()
# {
#   gitFilePreview="git diff $@ --color=always -- {-1}"
#   git diff $@ --name-only | fzf -m --ansi --preview "$gitFilePreview"
# }
# fd()
# {
#   if git rev-parse --git-dir > /dev/null 2>&1; then
#     if [ -d .git ]; then
#       showPreview > /dev/null
#     else
#       gitRepoDir=$(git rev-parse --git-dir | sed 's/.git//')
#       pushd $gitRepoDir > /dev/null
#       showPreview > /dev/null
#       popd > /dev/null
#     fi
#   else
#     echo "Error: Not inside a git repository."
#   fi
# }
#
# # Shell integrations
# eval "$(fzf --zsh)"
# eval "$(starship init zsh)"
# eval "$(atuin init zsh)"
# # eval "$(zoxide init zsh)"
# if [[ "$CLAUDECODE" != "1" ]]; then
#     eval "$(zoxide init --cmd cd zsh)"
# fi
#
# # opencode
# export PATH=/home/dalton/.opencode/bin:$PATH
# eval "$(uv generate-shell-completion zsh)"
export PATH="$HOME/bin:$PATH"

# zoxide last — doctor warns if anything follows it
command -v zoxide >/dev/null && eval "$(zoxide init --cmd cd zsh)"
