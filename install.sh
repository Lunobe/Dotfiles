#!/bin/bash
set -e

#  ___           _        _ _
# |_ _|_ __  ___| |_ __ _| | |
#  | || '_ \/ __| __/ _` | | |
#  | || | | \__ \ || (_| | | |
# |___|_| |_|___/\__\__,_|_|_|
##########################################################

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DOTFILES_DIR/bootstrap/lib.sh"

confirm() {
    local prompt="$1"
    read -rp "$prompt [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

echo "==> Dotfiles directory: $DOTFILES_DIR"

if confirm "Install packages from bootstrap/packages.txt?"; then
    INSTALL_EXCLUDE=("linux-cachyos" "linux-cachyos-headers")
    install_packages "$DOTFILES_DIR/bootstrap/packages.txt"
fi

if confirm "Deploy dotfiles via stow?"; then
    deploy_dotfiles "$DOTFILES_DIR"
fi

echo "==> Done"
