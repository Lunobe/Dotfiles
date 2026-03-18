#!/bin/bash

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

echo -e "\n\n\n\nBackup saved in: $BACKUP_DIR"
echo ""

stow -v -t ~/.config/ config/
stow -v -t ~/.local/ local/
stow -v -t ~ bash/

echo -e "\nDone.\n\n\n\n"
