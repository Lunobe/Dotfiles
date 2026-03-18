#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/$(date '+%Y-%m-%d_%H-%M-%S')-dotfiles-backup"

# ──────────────────────────────────────────────
# 1. Optional package installation
# ──────────────────────────────────────────────
read -rp "Install packages from packages.txt? [y/N] " install_pkgs
if [[ "$install_pkgs" =~ ^[Yy]$ ]]; then
    if ! command -v yay &>/dev/null; then
        echo "yay not found — installing yay first..."
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
        cd ..
        rm -rf yay
    fi
    echo "Installing packages..."
    yay -S --needed --noconfirm - < "$DOTFILES_DIR/packages.txt"
fi

# ──────────────────────────────────────────────
# 2. Back up conflicting directories/files
# ──────────────────────────────────────────────

# Map: <stow package dir> → <stow target dir>
declare -A STOW_TARGETS=(
    ["$DOTFILES_DIR/bash"]="$HOME"
    ["$DOTFILES_DIR/config"]="$HOME/.config"
    ["$DOTFILES_DIR/local"]="$HOME/.local"
)

needs_backup=false

for pkg_dir in "${!STOW_TARGETS[@]}"; do
    target="${STOW_TARGETS[$pkg_dir]}"
    while IFS= read -r -d '' entry; do
        # Relative path inside the package
        rel="${entry#$pkg_dir/}"
        dest="$target/$rel"
        # Back up only if dest exists and is NOT already a stow symlink pointing here
        if [[ -e "$dest" || -L "$dest" ]]; then
            if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$entry" ]]; then
                continue  # already correctly stowed
            fi
            needs_backup=true
            break 2
        fi
    done < <(find "$pkg_dir" -mindepth 1 -maxdepth 1 -print0)
done

if $needs_backup; then
    echo "Backing up conflicting files/dirs to: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    for pkg_dir in "${!STOW_TARGETS[@]}"; do
        target="${STOW_TARGETS[$pkg_dir]}"
        while IFS= read -r -d '' entry; do
            rel="${entry#$pkg_dir/}"
            dest="$target/$rel"
            if [[ -e "$dest" || -L "$dest" ]]; then
                if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$entry" ]]; then
                    continue
                fi
                backup_dest="$BACKUP_DIR/$rel"
                mkdir -p "$(dirname "$backup_dest")"
                echo "  Backing up: $dest → $backup_dest"
                mv "$dest" "$backup_dest"
            fi
        done < <(find "$pkg_dir" -mindepth 1 -maxdepth 1 -print0)
    done
else
    echo "No conflicting files found — skipping backup."
fi

# ──────────────────────────────────────────────
# 4. Stow dotfiles
# ──────────────────────────────────────────────
mkdir -p "$HOME/.config" "$HOME/.local"

echo "Stowing dotfiles..."
stow -d "$DOTFILES_DIR" -t "$HOME"       bash
stow -d "$DOTFILES_DIR" -t "$HOME/.config" config
stow -d "$DOTFILES_DIR" -t "$HOME/.local"  local

echo "Done."
