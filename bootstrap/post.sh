#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"

read -rp "==> run mode -- [a] apply all stages / [s] select each stage: " _run_mode
AUTO_CONFIRM=false
case "$_run_mode" in
    [aA]) AUTO_CONFIRM=true; log "mode: apply-all" ;;
    *)    log "mode: interactive" ;;
esac

confirm() {
    [[ "$AUTO_CONFIRM" == true ]] && return 0
    read -rp "$1 [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

process_units() {
    local file="$1" mode_flag="$2"
    local -a skip_now=("sddm" "sddm.service" "gdm" "lightdm" "ly")
    local sudo_prefix="sudo"

    [[ -f "$file" ]] || { warn "$file not found, skipping"; return; }
    [[ -n "$mode_flag" ]] && sudo_prefix=""
    log "Processing $file"

    while IFS= read -r unit || [[ -n "$unit" ]]; do
        [[ -z "$unit" || "$unit" =~ ^# ]] && continue

        local use_now="--now"
        for s in "${skip_now[@]}"; do [[ "$unit" == "$s" ]] && use_now="" && break; done

        if ! $sudo_prefix systemctl $mode_flag cat "$unit" &>/dev/null; then
            info "skipping $unit: unit file not found"
            continue
        fi
        $sudo_prefix systemctl $mode_flag enable $use_now "$unit"
    done < "$file"
}

ROOT_FS=$(findmnt -n -o FSTYPE /)

if [[ "$ROOT_FS" != "btrfs" ]]; then
    log "Skipping snapper setup: root filesystem is $ROOT_FS, not btrfs"
else
    if confirm "Configure snapper and btrfs snapshots?"; then
        log "Configuring snapper"
        sudo umount /{.snapshots,home/.snapshots} 2>/dev/null || true
        sudo rmdir /{.snapshots,home/.snapshots} 2>/dev/null || true
        sudo snapper -c root create-config /
        sudo snapper -c home create-config /home
        sudo rmdir /{.snapshots,home/.snapshots} 2>/dev/null || true
        sudo mkdir /{.snapshots,home/.snapshots}
        sudo mount -a
        sudo snapper -c root create --description "clean install"
        sudo snapper -c home create --description "clean install"
        sudo systemctl enable --now grub-btrfsd
        sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi

if confirm "Add CachyOS repositories to pacman?"; then
    log "Setting up CachyOS repositories"

    CACHY_MIRROR="https://mirror.cachyos.org/repo/x86_64/cachyos"
    MIRROR_INDEX=$(curl -fsSL "$CACHY_MIRROR/") || die "Failed to reach CachyOS mirror"
    [[ -n "$MIRROR_INDEX" ]] || die "Empty response from CachyOS mirror"

    # Returns the full URL of the latest version-sorted match from the mirror index.
    get_pkg_url() {
        local pkg
        pkg=$(echo "$MIRROR_INDEX" | grep -oP "href=\"\K${1}" | sort -V | tail -1)
        echo "$CACHY_MIRROR/$pkg"
    }

    # Manually import the GPG key before installing the keyring package — pacman
    # needs the key to verify the package it is about to install.
    KEYRING_PKG=$(echo "$MIRROR_INDEX" | grep -oP 'href="\Kcachyos-keyring-[^"]+\.pkg\.tar\.zst' | sort -V | tail -1)
    KEYRING_TMPDIR=$(mktemp -d)
    trap 'rm -rf "$KEYRING_TMPDIR"' EXIT
    curl -fsSL -o "$KEYRING_TMPDIR/$KEYRING_PKG" "$CACHY_MIRROR/$KEYRING_PKG"
    tar -xf "$KEYRING_TMPDIR/$KEYRING_PKG" -C "$KEYRING_TMPDIR"
    sudo pacman-key --add "$KEYRING_TMPDIR/usr/share/pacman/keyrings/cachyos.gpg"
    sudo pacman-key --lsign-key F3B607488DB35A47
    trap - EXIT
    rm -rf "$KEYRING_TMPDIR"

    sudo pacman -U \
        "$(get_pkg_url 'cachyos-keyring-[^"]+\.pkg\.tar\.zst')" \
        "$(get_pkg_url 'cachyos-mirrorlist-[0-9][^"]+\.pkg\.tar\.zst')" \
        "$(get_pkg_url 'cachyos-v3-mirrorlist-[^"]+\.pkg\.tar\.zst')" \
        "$(get_pkg_url 'cachyos-v4-mirrorlist-[^"]+\.pkg\.tar\.zst')" \
        "$(get_pkg_url 'pacman-[0-9][^"]+x86_64\.pkg\.tar\.zst')"

    cpu_level() {
        local ld="/lib/ld-linux-x86-64.so.2"
        if $ld --help 2>/dev/null | grep -q "x86-64-v4 (supported"; then
            if grep -m1 "model name" /proc/cpuinfo | grep -qiE "zen[[:space:]]*[45]|znver[45]"; then
                echo "znver4"
            else
                echo "v4"
            fi
        elif $ld --help 2>/dev/null | grep -q "x86-64-v3 (supported"; then
            echo "v3"
        else
            echo "base"
        fi
    }

    CPU_LEVEL=$(cpu_level)
    log "CPU level: $CPU_LEVEL"

    if grep -q '^\[cachyos\]' /etc/pacman.conf; then
        warn "CachyOS repos already in pacman.conf, skipping injection"
    else
        case "$CPU_LEVEL" in
            znver4)
                read -r -d '' CACHY_BLOCK << 'EOT' || true
[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOT
                ;;
            v4)
                read -r -d '' CACHY_BLOCK << 'EOT' || true
[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOT
                ;;
            v3)
                read -r -d '' CACHY_BLOCK << 'EOT' || true
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOT
                ;;
            *)
                read -r -d '' CACHY_BLOCK << 'EOT' || true
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOT
                ;;
        esac

        awk -v r="$CACHY_BLOCK" '
            /^\[core\]/ { print r }
            { print }
        ' /etc/pacman.conf | sudo tee /etc/pacman.conf.new >/dev/null
        sudo mv /etc/pacman.conf.new /etc/pacman.conf
    fi

    sudo pacman -Syyuu
fi

if confirm "Install packages from packages.txt?"; then
    INSTALL_EXCLUDE=("linux-cachyos" "linux-cachyos-headers" "fish" "ufw" "docker" "docker-compose" "vmware-workstation")
    install_packages "$SCRIPT_DIR/packages.txt"
fi

if confirm "Enable systemd units?"; then
    process_units "$SCRIPT_DIR/systemctl-root.txt" ""
    process_units "$SCRIPT_DIR/systemctl-user.txt" "--user"
fi

if confirm "Deploy dotfiles via stow?"; then
    read -rp "Dotfiles path [/home/$USER/Dotfiles]: " dot_path
    dot_path="${dot_path:-/home/$USER/Dotfiles}"
    [[ ! -d "$dot_path" ]] && git clone https://github.com/Lunobe/Dotfiles "$dot_path"
    deploy_dotfiles "$dot_path"
fi

if confirm "Install linux-cachyos and set as default kernel?"; then
    log "Installing linux-cachyos"
    yay -S --needed linux-cachyos linux-cachyos-headers
    log "Updating GRUB config"
    sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT="Arch Linux, with Linux linux-cachyos"/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

if confirm "Set fish as default shell?"; then
    ensure_pkg fish
    sudo chsh "$USER" -s /usr/bin/fish
fi

if confirm "Configure UFW firewall and install ufw-docker?"; then
    ensure_pkg ufw
    sudo ufw enable
    sudo curl -fsSL -o /usr/local/bin/ufw-docker \
        https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
    sudo chmod +x /usr/local/bin/ufw-docker
    sudo ufw-docker install
    sudo systemctl restart ufw
fi

if confirm "Install and configure Docker?"; then
    ensure_pkg docker
    ensure_pkg docker-compose
    sudo systemctl enable --now docker containerd
    sudo usermod -aG docker "$USER"
fi

if confirm "Install Claude Code?"; then
    log "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
fi

if confirm "Install VMware Workstation?"; then
    log "Installing VMware Workstation"
    mkdir -p ~/Repos
    # Subshell isolates the cd so the parent shell's cwd is unaffected
    (
        cd ~/Repos
        yay -G vmware-workstation
        cd vmware-workstation/
        sed -i 's/#_remove_vmware_keymaps_dependency=y/_remove_vmware_keymaps_dependency=y/' PKGBUILD
        makepkg -si
    )
    sudo modprobe -a vmw_vmci vmmon
    sudo systemctl enable --now vmware-networks vmware-usbarbitrator
fi

log "Done"
