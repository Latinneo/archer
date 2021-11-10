#!/bin/bsh
HOSTNAME="zion"

# Make the symbolic link to the appropriate zone file.
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

# Generate /etc/adjtime to synchronize the system time to the hardware clock with the hwclock command.
hwclock --systohc

# Set the locale.
sed '177s/.//' /etc/locale.gen
locale-gen

# Create the /etc/locale.conf file.
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

# Set the hostname
echo $HOSTNAME >> /etc/hostname

# Configure hosts
echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME\n" >> /etc/hosts

# Set mkinitcpio.conf modules
sed -i 's/MODULES=()/MODULES=(btrfs amdgpu)/' /etc/mkinitcpio.conf

# Set mkinitcpio.conf binaries
sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/' /etc/mkinitcpio.conf

# Create a new initramfs
mkinitcpio -p linux

# Initialize Snapper
snapper -c root create-config /

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

# 4. Delete the subvolume automatically created by snapper.
btrfs subvolume delete /.snapshots

# 5. Remake the directory for mounting our snapshots subvolume.
mkdir /.snapshots

# 6. Remount our snapshots subvolume with mount -a which remounts all filesystems specified in /etc/fstab
mount -a

# 7. Adjust permissions of /.snapshots
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
ROOT_PASSWORD_SET=0

while [ $ROOT_PASSWORD_SET -eq 0 ]
do
    echo -n "Enter password for root: "
    read -s ROOT_PASSWORD_1
    echo
    read -s -p "Retype password for confirmation: " ROOT_PASSWORD_2
    echo
    if [ $ROOT_PASSWORD_1 == $ROOT_PASSWORD_2 ];
    then
        echo root:$ROOT_PASSWORD_1 | chpasswd
        ROOT_PASSWORD_SET=1
    else
        echo "Passwords do not match."
    fi
done


# 2. Allow newly created users that are added to the wheel user group as a supplementary user group during
# creation to use sudo to execute commands with elevated privileges.
echo "wheel ALL=(ALL) ALL" >> /etc/sudoers.d/99_wheel
chmod 440 /etc/sudoers.d/99_wheel

# 3. Create Users
USER_NAME=ariel
USER_DESCRIPTION="Ariel de Llano"
USER_PASSWORD_SET=0

useradd -m -G wheel,docker -s $(which zsh) -c $USER_DESCRIPTION $USER_NAME

while [ $USER_PASSWORD_SET -eq 0 ]
do
    echo -n "Enter password for user '$USER_NAME': "
    read -s USER_PASSWORD_1
    echo
    read -s -p "Retype password for confirmation: " USER_PASSWORD_2
    echo
    if [ $USER_PASSWORD_1 == $USER_PASSWORD_2 ];
    then
        echo $USER_NAME:$USER_PASSWORD_1 | chpasswd
        $USER_PASSWORD_SET=1
    else
        echo "Passwords do not match."
    fi
done

echo $USER_NAME:$USER_PASSWORD_1 | chpasswd

sensors-detect --auto

# Configure and Enable Services
##########################################################################################################

# 1. Enable NetworkManager
systemctl enable NetworkManager.Services

# 2. Enable firewalld
systemctl enable firewalld

# 3. Enable bluetooth (and all controllers when they are found so bluetooth is available in sddm)
sed -i '250s/.//' /etc/bluetooth/main.conf
systemctl enable bluetooth.

# 4. Enable cups (via socket activation)
systemctl enable cups.socket

# 5. Enable sshd
systemctl enable sshd

# 6. Enable avahi
systemctl enable avahi-daemon

# 7. Configure and enable reflector (via timer)
sed -i 's/#--country.*/--country US/' /etc/xdg/reflector/reflector.conf
systemctl enable reflector.timer

# 8. Enable libvirtd
systemctl enable libvirtd

# 9. Enable docker
echo -e "{\n\t\"storage-driver\": \"btrfs\"\n}" >> /etc/docker/daemon.json
systemctl enable docker.service
systemctl enable containerd.service

# 10. Enable acpid
systemctl enable acpid

# 11. Enable SDDM, the Plasma desktop environments display manager.
systemctl enable ssdm

# copy aur.sh to user's home folder
curl -o /home/ariel/aur.sh -fsSL https://raw.github.com/Latinneo/archer/master/finalize.sh
chown ariel:ariel /home/ariel/finalize.sh
chmod 700 /home/ariel/finalize.sh

# Display success
echo "Installation is complete, you can reboot now!"