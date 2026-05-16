#!/bin/bash

set -euo pipefail

DEFAULT_DRIVE="/dev/nvme0n1"
DEFAULT_BOOT_SIZE="2G"
DEFAULT_ROOT_LABEL="Archy"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

die()  { echo "error: $*" >&2; exit 1; }
warn() { echo "warning: $*" >&2; }
log()  { echo "==> $*"; }

confirm() {
    read -rp "$1 [y/N]: " response
    [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]] || { echo "aborted"; exit 1; }
}

ask_param() {
    local prompt="$1" default="$2" input
    read -rp "==> $prompt [$default]: " input
    echo "${input:-$default}"
}

validate_pkgs() {
    local pkgs="$1" fs="$2"
    local -a essential=("base" "linux")
    [[ "$fs" == "btrfs" ]] && essential+=("btrfs-progs")
    for item in "${essential[@]}"; do
        [[ " $pkgs " == *" $item "* ]] || die "required package '$item' not in package list — system will not boot"
    done
}

clear
log "Installation parameters"

DRIVE=$(ask_param "Target drive" "$DEFAULT_DRIVE")
BOOT_SIZE=$(ask_param "Boot partition size" "$DEFAULT_BOOT_SIZE")
ROOT_LABEL=$(ask_param "Root label" "$DEFAULT_ROOT_LABEL")

echo
echo "  [1] btrfs  -- subvolumes, zstd compression, snapshot support"
echo "  [2] ext4   -- simple, stable"
read -rp "==> filesystem [1]: " fs_choice
case "${fs_choice:-1}" in
    2) FS="ext4" ;;
    *) FS="btrfs" ;;
esac
log "Filesystem: $FS"

CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
[[ "$CPU_VENDOR" == "GenuineIntel" ]] && DEFAULT_UCODE="intel-ucode" || DEFAULT_UCODE="amd-ucode"
UCODE=$(ask_param "CPU microcode" "$DEFAULT_UCODE")
log "Microcode: $UCODE"

if [[ "$FS" == "btrfs" ]]; then
    DEFAULT_PKGS="base linux linux-firmware linux-headers base-devel git vim btrfs-progs $UCODE networkmanager inotify-tools grub grub-btrfs efibootmgr snapper"
else
    DEFAULT_PKGS="base linux linux-firmware linux-headers base-devel git vim $UCODE networkmanager inotify-tools grub efibootmgr"
fi

log "Default packages: $DEFAULT_PKGS"
PKGS_INPUT=$(ask_param "Packages" "$DEFAULT_PKGS")

validate_pkgs "$PKGS_INPUT" "$FS"
read -ra PKGS <<< "$PKGS_INPUT"

echo -e "\nwarning: all data on $DRIVE will be destroyed"
confirm "Proceed with installation?"

log "Wiping disk signatures"
wipefs -a "$DRIVE"

log "Partitioning $DRIVE"
sfdisk "$DRIVE" <<EOF
label: gpt
device: $DRIVE
unit: sectors

1 : size=$BOOT_SIZE, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
2 : type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

partprobe "$DRIVE"

if [[ "$DRIVE" == *nvme* ]]; then
    PART1="${DRIVE}p1"
    PART2="${DRIVE}p2"
else
    PART1="${DRIVE}1"
    PART2="${DRIVE}2"
fi

log "Formatting partitions"
mkfs.fat -F32 "$PART1"

if [[ "$FS" == "btrfs" ]]; then
    mkfs.btrfs -L "$ROOT_LABEL" -f "$PART2"

    log "Creating btrfs subvolumes"
    mount "$PART2" /mnt
    btrfs subvol create /mnt/@
    btrfs subvol create /mnt/@home
    btrfs subvol create /mnt/@cache
    btrfs subvol create /mnt/@log
    btrfs subvol create /mnt/@snapshots
    btrfs subvol create /mnt/@home_snapshots
    umount /mnt

    log "Mounting subvolumes"
    mount -o noatime,compress=zstd,subvol=@ "$PART2" /mnt
    mkdir -p /mnt/{home,var/cache,var/log,.snapshots,boot/efi}
    mount -o noatime,compress=zstd,subvol=@home "$PART2" /mnt/home
    mkdir -p /mnt/home/.snapshots
    mount -o noatime,compress=zstd,subvol=@home_snapshots "$PART2" /mnt/home/.snapshots
    mount -o noatime,compress=zstd,subvol=@cache "$PART2" /mnt/var/cache
    mount -o noatime,compress=zstd,subvol=@log "$PART2" /mnt/var/log
    mount -o noatime,compress=zstd,subvol=@snapshots "$PART2" /mnt/.snapshots
else
    mkfs.ext4 -L "$ROOT_LABEL" "$PART2"

    log "Mounting root partition"
    mount -o noatime "$PART2" /mnt
    mkdir -p /mnt/{home,boot/efi}
fi

mount "$PART1" /mnt/boot/efi

confirm "Run pacstrap?"
log "Running pacstrap"
pacstrap -K /mnt "${PKGS[@]}"

log "Generating fstab"
genfstab -U /mnt > /mnt/etc/fstab

log "Base system installed to /mnt"

if [[ -f "$SCRIPT_DIR/chroot.sh" ]]; then
    read -rp "==> Enter chroot and continue setup? [y/N]: " chroot_confirm
    if [[ "$chroot_confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        cp "$SCRIPT_DIR/chroot.sh" /mnt/root/chroot.sh
        chmod +x /mnt/root/chroot.sh
        arch-chroot /mnt /root/chroot.sh
        rm /mnt/root/chroot.sh

        if [[ -f "$SCRIPT_DIR/post.sh" ]]; then
            NEW_USER=$(grep ":1000:1000:" /mnt/etc/passwd | cut -d: -f1 || true)
            NEW_USER="${NEW_USER:-lunobe}"
            USER_HOME="/mnt/home/$NEW_USER"

            if [[ -d "$USER_HOME" ]]; then
                log "Staging post-install scripts for $NEW_USER"
                cp "$SCRIPT_DIR"/{post.sh,lib.sh,packages.txt,systemctl-root.txt,systemctl-user.txt} "$USER_HOME/"
                chmod +x "$USER_HOME"/*.sh
                chown 1000:1000 "$USER_HOME"/{post.sh,lib.sh,packages.txt,systemctl-root.txt,systemctl-user.txt}
            else
                warn "home directory for '$NEW_USER' not found, skipping"
            fi
        fi
    fi
else
    warn "chroot.sh not found"
fi
