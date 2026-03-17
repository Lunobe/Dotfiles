#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export PATH="$HOME/.local/bin:$PATH"

# Nice package management
alias i='sudo pacman -S --needed --noconfirm'
alias s='sudo pacman -Ss'
alias r='sudo pacman -Rns --noconfirm'
alias q='sudo pacman -Qs'

# Extended ls commands
alias ll='ls -l'
alias la='ls -la'

# Extended cs commands
alias ..='cd ..'
alias ...='cd .. && cd ..'
alias ....='cd .. && cd .. && cd ..'
alias .....='cd .. && cd .. && cd .. && cd ..'

fastfetch
