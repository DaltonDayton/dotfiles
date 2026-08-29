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

# fzf completion on plain Tab instead of the `**` trigger. Omarchy sources
# fzf's completion.bash, which defaults FZF_COMPLETION_TRIGGER to `**`; the
# default uses ${VAR-...}, so an empty value is honored rather than ignored.
# Applies to fzf's registered commands (cd, nvim, git, ls, cp, rm, kill, ssh,
# export, ...) — everything else keeps normal bash completion.
export FZF_COMPLETION_TRIGGER=''
# Without this every Tab opens the picker, even for a single candidate.
export FZF_COMPLETION_OPTS='--select-1 --exit-0'
