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

alias cleanup='
    echo "--- 1. Removing orphan packages ---";
    sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null || echo "No orphan packages found.";
    
    echo "--- 2. Clearing the pacman cache (leaving both versions) ---";
    sudo paccache -rk2;
    
    echo "--- 3. Clearing the yay (AUR) cache ---";
    yay -Sc --noconfirm;
    
    echo "--- 4. Clearing the user cache (~/.cache) ---";
    find ~/.cache -type f -atime +7 -delete;
    
    echo "--- 5. Clearing Journald logs (leaving the last 2 days) ---";
    sudo journalctl --vacuum-time=2d;
    
    echo "Done! The system is shining."
'

alias pacmanfix='sudo rm /var/lib/pacman/db.lck'

fastfetch

# Created by `pipx` on 2026-03-18 21:08:50
export PATH="$PATH:/home/lunobe/Dotfiles/bin/.local/bin"
