#!/bin/bash

if ! command -v yay &> /dev/null; then
    read -p "yay not found. Do you want to install? (y/n): " install_yay
    if [[ "$install_yay" =~ ^[Yy]$ ]]; then
        echo "Downloading yay..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay || exit
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    else
        echo "Exiting..."
    fi
fi

if [ -f "packages.txt" ]; then
    read -p "Do you want to install all packages? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Downloading packages from packages.txt..."
        while IFS= read -r package || [ -n "$package" ]; do
            [[ -z "$package" || "$package" =~ ^# ]] && continue
            echo "Downloading: $package"
            yay -S --noconfirm --needed "$package"
        done < "packages.txt"
    else
        echo "Ok."
    fi
fi

BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

backup_and_remove() {
    local target_path="$1"
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        local relative_path=$(echo "$target_path" | sed "s|$HOME/||")
        mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
        mv "$target_path" "$BACKUP_DIR/$relative_path"
    fi
}

if [ -d "config" ]; then
    for item in config/*; do
        basename_item=$(basename "$item")
        backup_and_remove "$HOME/.config/$basename_item"
    done
fi

if [ -d "local" ]; then
    find local -maxdepth 2 -mindepth 1 | while read -r item; do
        target=$(echo "$item" | sed "s|^local|$HOME/.local|")        
        backup_and_remove "$target"
    done
fi

if [ -d "bash" ]; then
    for item in bash/.*; do
        [[ "$(basename "$item")" == "." || "$(basename "$item")" == ".." ]] && continue
        backup_and_remove "$HOME/$(basename "$item")"
    done
fi

echo -e "\nBackup saved in: $BACKUP_DIR\n"

stow -v -t ~/.config/ config/
stow -v -t ~/.local/ local/
stow -v -t ~ bash/

echo "Done"
