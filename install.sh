#!/usr/bin/env bash
set -e

DISK="/dev/sda"
HOST="archlinux"
USER="user"
PASSWORD="password"

echo "=== パーティション作成 ==="
sgdisk -Z $DISK
sgdisk -n 1:0:+512M -t 1:ef00 $DISK
sgdisk -n 2:0:0 -t 2:8300 $DISK

mkfs.fat -F32 ${DISK}1
mkfs.btrfs -f ${DISK}2

mount ${DISK}2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o subvol=@ ${DISK}2 /mnt
mkdir -p /mnt/{boot,home}
mount -o subvol=@home ${DISK}2 /mnt/home
mount ${DISK}1 /mnt/boot

echo "=== パッケージインストール ==="
pacstrap /mnt base linux linux-firmware btrfs-progs networkmanager sudo vim

echo "=== fstab 生成 ==="
genfstab -U /mnt >> /mnt/etc/fstab

echo "=== chroot 内設定 ==="
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
hwclock --systohc

sed -i 's/#ja_JP.UTF-8/ja_JP.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=ja_JP.UTF-8" > /etc/locale.conf

echo "$HOST" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOST.localdomain $HOST" >> /etc/hosts

echo "=== systemd-boot インストール ==="
bootctl install

cat <<BOOT > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value ${DISK}2) rootflags=subvol=@ rw
BOOT

echo "=== ユーザー作成 ==="
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel $USER
echo "$USER:$PASSWORD" | chpasswd
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

systemctl enable NetworkManager
EOF

echo "=== 完了！再起動してください ==="
