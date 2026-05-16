#!/bin/bash

set -euo pipefail

DEFAULT_ZONE="/usr/share/zoneinfo/Asia/Jerusalem"
DEFAULT_HOSTNAME="fsociety"
DEFAULT_USER="lunobe"
DEFAULT_LOCALE="en_US.UTF-8"

log() { echo "==> $*"; }

confirm() {
    read -rp "$1 [y/N]: " response
    [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]] || { echo "skipped"; return 1; }
}

ask_param() {
    local prompt="$1" default="$2" input
    read -rp "==> $prompt [$default]: " input
    echo "${input:-$default}"
}

ZONE=$(ask_param "Timezone" "$DEFAULT_ZONE")
ln -sf "$ZONE" /etc/localtime
hwclock --systohc
log "Timezone: $ZONE"

LOCALE=$(ask_param "Locale" "$DEFAULT_LOCALE")
sed -i "/^#$LOCALE/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
log "Locale: $LOCALE"

HOSTNAME=$(ask_param "Hostname" "$DEFAULT_HOSTNAME")
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
log "Hostname: $HOSTNAME"

log "Set root password"
passwd

USERNAME=$(ask_param "Username" "$DEFAULT_USER")
useradd -m -G wheel -s /bin/bash "$USERNAME"
log "Set password for $USERNAME"
passwd "$USERNAME"

# sudoers editing via sed is safe here since we own the chroot environment
if [[ -f /etc/sudoers ]]; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
fi

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
