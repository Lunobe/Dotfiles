source ~/.config/fish/conf.d/config.fish
# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# Nice package management
alias i='yay -S --needed --noconfirm'
alias s='yay -Ss'
alias r='yay -Rns --noconfirm'
alias q='yay -Qs'

# Extended cs commands
alias pacmanfix='sudo rm /var/lib/pacman/db.lck'

alias l='eza -1 --icons'
alias c='clear'
alias cl='clear'

alias img='chafa'

alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'

alias myip='curl ifconfig.me'
alias localip='ip -br addr show | grep UP'
alias active='sudo ss -tpn state established'
alias ports='sudo ss -tulanp'

alias find='fd -H'
alias cat='bat --paging=never'
alias grep='rg --color=auto'
function findtext
    rg -i --trim $argv
end

alias usage='sudo ncdu -x /'
alias usagehome='sudo ncdu -x /home'

set -gx EDITOR vim
set -gx VISUAL vim
if status is-interactive
    keychain --eval --quiet --agents ssh github
    
    if test -f ~/.keychain/(hostname)-fish
        source ~/.keychain/(hostname)-fish
    end
end
alias svim='sudoedit'
alias mc='mcrcon -H localhost -P 25575 -p' 
