#!/bin/bash
HOSTNAME="zion"

# System Configuration
##########################################################################################################

# 1. Make the symbolic link to the appropriate zone file.
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

# 2. Generate /etc/adjtime to synchronize the system time to the hardware clock with the hwclock command.
hwclock --systohc

# 3. Set the locale.
sed -i '177s/.//' /etc/locale.gen
locale-gen

# 4. Create the /etc/locale.conf file.
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

# 5. Set the hostname
echo $HOSTNAME >> /etc/hostname

# 6. Configure hosts
echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME\n" >> /etc/hosts

# 7. Set mkinitcpio.conf modules
sed -i 's/MODULES=()/MODULES=(btrfs amdgpu)/' /etc/mkinitcpio.conf

# 8. Set mkinitcpio.conf binaries
sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/' /etc/mkinitcpio.conf

# 9. Create a new initramfs
mkinitcpio -p linux

# Initialize Snapper
##########################################################################################################
#
# snapper -c root create-config /
#
# This creates a configuration file named /etc/snapper/configs/root for snapshotting the subvolume
# mounted at / by copying /etc/snapper/config-templates/default. It also creates a subvolume named
# .snapshots in the subvolume mounted at / and makes the directory /.snapshots to which to mount it.
# For the command to complete successfully, thus enabling snapshotting of the subvolume mounted at /,
#
#   1. there must not be a subvolume with the same name as the subvolume Snapper wants to create inside
#      the subvolume mounted at root.
#   2. the directory /.snapshots must not exist
#   3. the configuration file has to be created at the approproate location, which requires conditoins
#      #1 and #2 to be satisfied
#
# So we must perform the actions below to "trick" Snapper into making the configuration file, by first
# unmounting the /@/.snapshots subvolume, deleting its mountpoint (/.snapshots), running the Snapper
# configuraiton command, deleting the subvolume created by Snapper, remaking the mountpoint, and finally
# remounting our original /@/snapshots subvolume. For those wondering why the configuration file can't
# be copied manually, and the name of the configuration added to /etc/conf.d/snapper, it is possible,
# but Snapper commands result in errors.

# 1. Unount the @/.snapshots subvolume from /.snapshots.
umount /.snapshots

# 2. Remove the directory that was the mountpoint of the @/.snapshots subvolume. Removing the directory
#    does not delete the subvolume since it was unmounted in the last command.
rm -r /.snapshots

# 3. Issue the Snapper command to initialize a configuration named root for a subvolume mounted at /.
#    The --no-dbus option is required because we are running in a chroot environemnt to the system and
#    not the actual system.
snapper --no-dbus -c root create-config /

# 4. Edit Snapper Configuration
sed -i 's/QGROUP=""/QGROUP="1\/0"/' /etc/snapper/configs/root
sed -i 's/NUMBER_LIMIT="50"/NUMBER_LIMIT="10-35"/' /etc/snapper/configs/root
sed -i 's/NUMBER_LIMIT_IMPORTANT="50"/NUMBER_LIMIT_IMPORTANT="15-25"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="2"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="3"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

# 5. Delete the subvolume automatically created by snapper.
btrfs subvolume delete /.snapshots

# 6. Remake the directory for mounting our snapshots subvolume.
mkdir /.snapshots

# 7. Remount our snapshots subvolume with mount -a which remounts all filesystems specified in /etc/fstab
mount -a

# 8. Adjust permissions of /.snapshots
chmod 750 /.snapshots


# Install Bootloader
##########################################################################################################

# 1. Enable os-prober
echo -e '\nGRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub

# 2. Install the GRUB firmware bootloader on the ESP.
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARCH-ZION --modules="normal test efi_gop efi_uga search echo linux all_video gfxmenu gfxterm_background gfxterm_menu gfxterm loadenv configfile gzio part_gpt btrfs"

# 3. Update the GRUB configuration.
grub-mkconfig -o /boot/grub/grub.cfg


# User Configuration
##########################################################################################################

# 1. Create the root user's password.
echo -e "Setting password for root...\n"
passwd

# 2. Allow newly created users that are added to the wheel user group as a supplementary user group during
# creation to use sudo to execute commands with elevated privileges.
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers.d/99_wheel
chmod 440 /etc/sudoers.d/99_wheel

# 3. Create User
USER_NAME=ariel
USER_DESCRIPTION="Ariel de Llano"

useradd -mG wheel,docker -s $(which zsh) -c "$USER_DESCRIPTION" $USER_NAME

# 4. Set User's Password
echo -e "Setting password for user '$USER_NAME'...\n"

passwd $USER_NAME

# Configure and Enable Services
##########################################################################################################
# 1. Detect hardware sensors
sensors-detect --auto

# 2. Enable NetworkManager
systemctl enable NetworkManager.service

# 3. Enable firewalld
systemctl enable firewalld

# 4. Enable bluetooth (and all controllers when they are found so bluetooth is available in sddm)
sed -i '250s/.//' /etc/bluetooth/main.conf
systemctl enable bluetooth

# 5. Enable cups (via socket activation)
systemctl enable cups.socket

# 6. Enable sshd
systemctl enable sshd

# 7. Enable avahi
systemctl enable avahi-daemon

# 8. Enable libvirtd
systemctl enable libvirtd.service

# 9. Configure and enable reflector (via timer)
sed -i 's/#--country.*/--country US/' /etc/xdg/reflector/reflector.conf
systemctl enable reflector.timer

# 10. Enable docker
echo -e "{\n\t\"storage-driver\": \"btrfs\"\n}" >> /etc/docker/daemon.json
systemctl enable docker.service
systemctl enable containerd.service

# 11. Enable acpid
systemctl enable acpid
