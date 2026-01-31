#/bin/bash

set -eao pipefail

timedatectl

partition_disk() {
  read -p "Wich disk would you like to partition (eg. nvme0n1,sda,sdb) ? " disk_name
  fdisk /dev/${disk_name}
  read -p "What's the name of the root partition (/) ?" root_part_name
  mkfs.btrfs /dev/${root_part_name}
  read -p "What's the name of the EFI partition (efi) ?" efi_part_name
  mkfs.fat -F32 /dev/${efi_part_name}
  mount /dev/${root_part_name} /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@var
  umount /mnt
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@ /dev/${root_part_name} /mnt
  mkdir -p /mnt/{boot,home,var}
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@home /dev/${root_part_name} /mnt/home
  mount -o noatime,compress=zstd,ssd,discard=async,space_cache=v2,subvol=@var /dev/${root_part_name} /mnt/var
  mount /dev/${efi_part_name} /mnt/boot
  reflector --sort rate --completion-percent 100 --age 12 --country France --protocol https --save /etc/pacman.d/mirrorlist
  pacstrap -K /mnt base linux linux-firmware git vim sof-firmware intel-ucode btrfs-progs sudo networkmanager
  genfstab -U /mnt >> /mnt/etc/fstab
  hwclock --systohc
}

install_core() {
  ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
  vim /etc/locale.gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf
  echo "KEYMAP=us" > /etc/vconsole.conf
  locale-gen
  echo "archlinux" > /etc/hostname
  echo "127.0.0.1\tlocahost" > /etc/hosts
  echo "::1\tlocahost" > /etc/hosts
  echo "127.0.0.1\tarchlinux.localdomain\tarchlinux" > /etc/hosts
  vim /etc/mkinitcpio.conf
  mkinitcpio -P
  passwd
  read -p "New user name: " new_username
  useradd -mG wheel ${new_username}
  passwd ${new_username}
  EDITOR=vim visudo
  pacman -S refind
  refind-install
  echo "+--------------------------------+"
  echo "                                  "
  echo "Don't forget to configure refind !"
  echo "                                  "
  echo "+--------------------------------+"
  sleep 2
  pacman -S wofi hyprland nvidia-open ghostty
  mkdir -p /home/${new_username}/.config/hypr
  cat <<EOF >> /home/${new_username}/.config/hypr/hyprland.conf
monitor=eDP-1,disabled
monitor=DP-1,disabled
monitor=HDMI-A-1,1920x1080,auto,1

input {
  kb_layout = us
}

animations {
  enabled = true
}

\$mainMod = SUPER
\$terminal = ghostty
\$menu = wofi --show drun

bind = \$mainMod, Return, exec, \$terminal
bind = \$mainMod, D, exec, \$menu

bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10

bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9
bind = \$mainMod SHIFT, 0, movetoworkspace, 10
EOF

  pacman -S lightdm lightdm-gtk-greeter

  systemctl enable lightdm.service
  systemctl enable NetworkManager.service

  echo "+---------------------------------+"
  echo "                                   "
  echo "Don't forget to configure lightdm !"
  echo "                                   "
  echo "+---------------------------------+"

  echo "After configuring Refind and LightDM, you can safely un-chroot and umount -R /mnt then reboot."
}

while true; do
  read -p "Want you to partition your disk or install the core system ? [partition/core] " install_part
  case $install_part in
    "partition")
      partition_disk
      break
      ;;
    "core")
      install_core
      break
      ;;
    *)
      echo "Please enter one of the following : [partition] or [core]."
      ;;
    esac
done
