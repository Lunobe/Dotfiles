#!/bin/bash
# Shared library for bootstrap scripts. Source this file; do not execute directly.

BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d_%H%M%S)"
EXCLUDE=(".git" ".gitignore" "bootstrap" "README.md" "wallpapers" "scripts")

declare -A TARGET_MAP=(
    ["config"]="$HOME/.config"
    ["local"]="$HOME/.local"
    ["bash"]="$HOME"
    ["vim"]="$HOME"
)

# Set before calling install_packages to exclude specific packages
INSTALL_EXCLUDE=()

log()  { echo "==> $*"; }
info() { echo "  -> $*"; }
warn() { echo "warning: $*" >&2; }
die()  { echo "error: $*" >&2; exit 1; }

# yay can't bootstrap itself via pacman — build from AUR source instead
ensure_pkg() {
    local pkg="$1"
    if [[ "$pkg" == "yay" ]]; then
        command -v yay &>/dev/null && return 0
        log "Installing yay"
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay
    else
        # pacman -Q checks the package DB, not just PATH — avoids false positives
        # from stubs or unrelated binaries with the same name.
        pacman -Q "$pkg" &>/dev/null && return 0
        log "Installing $pkg"
        # { yes || true; } answers the IgnorePkg prompt that --noconfirm silently skips (exit 0).
        # Plain "yes |" breaks with pipefail: yes gets SIGPIPE (exit 141) when pacman closes stdin.
        { yes || true; } | sudo pacman -S --needed "$pkg"
    fi
}

ensure_multilib() {
    grep -q '^\[multilib\]' /etc/pacman.conf && return 0
    log "Enabling multilib repository"
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy
}

install_packages() {
    local packages_file="$1"
    [[ -f "$packages_file" ]] || { warn "$packages_file not found, skipping"; return; }

    ensure_multilib
    ensure_pkg yay

    local -a pkgs=()
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        for ex in "${INSTALL_EXCLUDE[@]}"; do [[ "$pkg" == "$ex" ]] && continue 2; done
        pkgs+=("$pkg")
    done < "$packages_file"

    yay -S --needed "${pkgs[@]}"
}

deploy_dotfiles() {
    local dot_path="$1"
    ensure_pkg stow

    local backed_up=false

    for pkg_path in "$dot_path"/*/; do
        [[ -d "$pkg_path" ]] || continue
        local pkg
        pkg=$(basename "${pkg_path%/}")

        for ex in "${EXCLUDE[@]}"; do [[ "$pkg" == "$ex" ]] && continue 2; done

        local target="${TARGET_MAP[$pkg]:-$HOME}"
        mkdir -p "$target"

        while IFS= read -r source_item; do
            local item_name dest_item
            item_name=$(basename "$source_item")
            dest_item="$target/$item_name"
            if [[ -e "$dest_item" || -L "$dest_item" ]]; then
                if [[ -L "$dest_item" && "$(readlink -f "$dest_item")" == "$(readlink -f "$source_item")" ]]; then
                    continue
                fi
                info "backing up: $dest_item"
                mkdir -p "$BACKUP_DIR"
                mv "$dest_item" "$BACKUP_DIR/"
                backed_up=true
            fi
        done < <(find "$dot_path/$pkg" -maxdepth 1 -mindepth 1)

        info "stow: $pkg -> $target"
        stow -d "$dot_path" -t "$target" "$pkg"
    done

    $backed_up && log "Backups written to $BACKUP_DIR"
}
