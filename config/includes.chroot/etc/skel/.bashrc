# Ravan Linux user shell configuration

case "$-" in
    *i*) ;;
      *) return ;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=2000
HISTFILESIZE=5000

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias update='sudo apt update && sudo apt upgrade'

if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b)"
fi

PS1='\[\e[1;35m\]\u@ravan\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '