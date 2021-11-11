
#!/bin/bash

# Enable network time synchronization.
timedatectl set-ntp true

ESP_PARTITION="/dev/nvme0n1p1"
ROOT_PARTITION="/dev/nvme0n1p4"
HOME_PARTITION="/dev/nvme0n1p5"
BACKUP_PARTITION="/dev/nvme0n1p6"

# Make root partition.
mkfs.btrfs -L ROOT -f -n 32k $ROOT_PARTITION

# Make the home partition
mkfs.ext4 -L HOME -f $HOME_PARTITION

ESP_UUID=$(lsblk -o UUID $ESP_PARTITION | grep -v UUID)
ROOT_UUID=$(lsblk -o UUID $ROOT_PARTITION | grep -v UUID)
HOME_UUID=$(lsblk -o UUID $HOME_PARTITION | grep -v UUID)
BACKUP_UUID=$(lsblk -o UUID $BACKUP_PARTITION | grep -v UUID)

# Mount system partition.
mount UUID=$ROOT_UUID /mnt

# The root directory is its own subvolume.
btrfs subvolume create /mnt/@

# The .snapshots subvolume will contain snapshots of the root filesystem.
btrfs subvolume create /mnt/@/.snapshots

# Create a subvolume for the initial snapshot which will be the target of the installation.
# First a directory inside the /@/.snapshots subvolume (accessed as /mnt/@/.snapshots inside
# our chroot environment) needs to be created that conforms to Snapper's expectations, which
# is that there exists a directory with the same name as the snapshot number within the
# /@/.snapshots subvolume for each snapshot.
mkdir /mnt/@/.snapshots/1

# Create first snapshot subvolume
btrfs subvolume create /mnt/@/.snapshots/1/snapshot

# Create a subvolume for the filesystem hierarchy in and under /boot/grub/.
# This will first require a directory /boot to be created.
mkdir /mnt/@/boot

# Create grub subvolume
btrfs subvolume create /mnt/@/boot/grub

# Third-party products usually get installed to /opt. This will exclude /opt and the filesystem
# hierarchy beneath it to be excluded from snapshots.
btrfs subvolume create /mnt/@/opt

# The root users home directory should also be preserved during a rollback.
btrfs subvolume create /mnt/@/root

# Create the /@/srv subvolume for the filesystem hierarchy under /srv which contains data for
# Web and FTP servers. It is excluded to avoid data loss on rollbacks.
btrfs subvolume create /mnt/@/srv

# Create the /@/tmp subvolume for the filesystem hierarchy under /tmp which contains temporary
# files and caches and is excluded from snapshots.
btrfs subvolume create /mnt/@/tmp

# Create a subvolume for filesystem hierarchy in and under /usr/local. This will first require
# a directory to be created at /@/usr.
mkdir /mnt/@/usr

# Create the subvolume
btrfs subvolume create /mnt/@/usr/local

# Create the /@/var/cache subvolume for filesystem hierarchy in and under /var/cache. This will
# first require a directory to be created at /@/var. where the subvolume will be created. The
# other subvolumes under /@/var will also be created at this location.
mkdir /mnt/@/var

# Create the subvolume
btrfs subvolume create /mnt/@/var/cache

# Create the /@/var/log subvolume for filesystem hierarchy in and under /var/log.
btrfs subvolume create /mnt/@/var/log

# Create the /@/var/spool subvolume for filesystem hierarchy in and under /var/spool.
btrfs subvolume create /mnt/@/var/spool

# Create the /@/var/tmp subvolume for filesystem hierarchy in and under /var/tmp
btrfs subvolume create /mnt/@/var/tmp

# Create the /@/var/lib/docker/volumes subvolume for filesystem hierarchy in and under /var/lib/docker/volumes.
# This will first require a directory to be created at /@/var/lib. where the subvolume will be created.
# The other subvolumes under /@/var/lib will also be created at this location.
mkdir -p /mnt/@/var/lib/docker

# Create the /@/var/lib/docker/volumes subvolume for filesystem hierarchy in and under /var/lib/docker/volumes.
btrfs subvolume create /mnt/@/var/lib/docker/volumes

# Create the /@/var/lib/libvirt/images subvolume for filesystem hierarchy in and under /var/lib/libvirt/images.
# This will first require a directory to be created at /@/var/lib/libvirt. where the subvolume will be created.
# The other subvolumes under /@/var/lib will also be created at this location.
mkdir /mnt/@/var/lib/libvirt

# Create the /@/var/lib/libvirt/images subvolue for filesystem hierarchy in and under /var/lib/libvirt/images
btrfs subvolume create /mnt/@/var/lib/libvirt/images

# The /@/swap subvolume contains the system swapfile which must be excluded from snapshots.
btrfs subvolume create /mnt/@/swap

# Snapper stores metadata for each snapshot in the snapshot's directory /@/.snapshots/# where "#"
# represents the snapshot number in an .xml file. For our initial snapshot this will be /@/.snapshots/1
# One of the metadata items is the snapshot creation time, in the format YYYY-MM-DD HH:MM:SS.
# The current date and time string in the appropriate format can be obtained with the command:

CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")
echo -e "<?xml version=\"1.0\"?> \n\
<snapshot> \n\
	<type>single</type> \n\
	<num>1</num> \n\
	<date>$CURRENT_DATE</date> \n\
	<description>First Root Filesystem Created at Installation</description> \n\
</snapshot>" >> /mnt/@/.snapshots/1/info.xml

# Set the default subvolume to the initial installation snapshot.
btrfs subvolume set-default $(btrfs subvolume list /mnt | grep "@/.snapshots/1/snapshot" | grep -oP '(?<=ID )[0-9]+') /mnt

# Enable quotas in the Btrfs filesystem. Quota's are required for the Snapper's snapshot cleanup
# algorithms that are based on an awareness of space on the filesystem. The Btrfs wiki does list
# some known issues to be aware of before enabling qgroups. man btrfs-qgroup also has a warning
#regarding btrfs qgroup
btrfs quota enable /mnt

# Disable copy-on-write for the /@/var subvolumes this will require the nodatacow mount option,
# which will disable compression for these subvolumes.
chattr +C /mnt/@/var/cache
chattr +C /mnt/@/var/log
chattr +C /mnt/@/var/spool
chattr +C /mnt/@/var/tmp
chattr +C /mnt/@/var/lib/docker/volumes
chattr +C /mnt/@/var/lib/libvirt/images

# Disable copy-on-write for the /@/swap subvolume
chattr +C /mnt/@/swap

# Unmount the Btrfs filesystem.
umount /mnt

# Mount the Btrfs filesystem again
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async /mnt

# Create mountpoints
mkdir -p /mnt/{.snapshots,backup,boot/{efi,grub},home,opt,root,srv,tmp,usr/local,var/{cache,log,spool,tmp,lib/{docker/volumes,libvirt/images}},swap}

# Mount @/.snapshots subvolume
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async,discard=async,subvol=@/.snapshots /mnt/.snapshots

# Mount BACKUP partition
mount UUID=$BACKUP_UUID /mnt/backup

# Mount the ESP partition.
mount UUID=$ESP_UUID /mnt/boot/efi

# Mount @/boot/grub subvolume
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@/boot/grub /mnt/boot/grub

# Mount the HOME partition
mount UUID=$HOME_UUID /mnt/home

# Mount @/opt subvolume
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@/opt /mnt/opt

# Mount @/root subvolume
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@/root /mnt/root

# Mount @/srv subvolume
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@/srv /mnt/srv

# Mount @/tmp subvolume
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@/tmp /mnt/tmp

# Mount the @/usr/local subvolume
mount UUID=$ROOT_UUID -o noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@/usr/local /mnt/usr/local

# Mount the @/var/cache subvolume
mount UUID=$ROOT_UUID -o noatime,nodatacow,discard=async,subvol=@/var/cache /mnt/var/cache

# Mount the @/var/log subvolume
mount UUID=$ROOT_UUID -o noatime,nodatacow,discard=async,subvol=@/var/log /mnt/var/log

# Mount the @/var/spool subvolume
mount UUID=$ROOT_UUID -o noatime,nodatacow,discard=async,subvol=@/var/spool /mnt/var/spool

# Mount the @/var/tmp subvolume
mount UUID=$ROOT_UUID -o noatime,nodatacow,discard=async,subvol=@/var/tmp /mnt/var/tmp

# Mount the @/var/lib/docker/volumes subvolume
mount UUID=$ROOT_UUID -o noatime,nodatacow,discard=async,subvol=@/var/lib/docker/volumes /mnt/var/lib/docker/volumes

# Mount the @/var/lib/libvirt/images subvolume
mount UUID=$ROOT_UUID -o noatime,nodatacow,discard=async,subvol=@/var/lib/libvirt/images /mnt/var/lib/libvirt/images

# Mount the @/swap subvolume
mount UUID=$ROOT_UUID -o noatime,nodatacow,discard=async,subvol=@/swap /mnt/swap

# Create swapfile
truncate -s 0 /mnt/swap/swapfile
chattr +C /mnt/swap/swapfile
btrfs property set /mnt/swap/swapfile compression none
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=2048 status=progress
chmod 600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile
swapon /mnt/swap/swapfile

# Install the base system
pacstrap /mnt base linux linux-firmware amd-ucode vim btrfs-progs ntfs-3g

# Install filesystem related tools
pacstrap /mnt mtools dosfstools nfs-utils

# Install booting related packages
pacstrap /mnt grub grub-btrfs os-prober efibootmgr

# Install hardware management packages
pacstrap /mnt acpi acpi_call acpid lm_sensors usbutils

# Install networking related packages
pacstrap /mnt networkmanager network-manager-applet wpa_supplicant avahi inetutils dnsutils nss-mdns openssh reflector

# Install snapper and snap-pac, which automatically makes Snapper snapshots after package manager transactions.
pacstrap /mnt snapper snap-pac

# Install video drivers
pacstrap /mnt xf86-video-amdgpu

# Install bluetooth
pacstrap /mnt bluez bluez-utils

# Install cups
pacstrap /mnt cups cups-pdf

# Install firewall
pacstrap /mnt firewalld ipset iptables-nft

# Install development related packages
pacstrap /mnt git github-cli docker docker-compose dotnet-sdk-3.1 aspnet-runtime-3.1

# Install additional programs
pacstrap /mnt base-devel linux-headers bash-completion zsh neofetch htop rsync

# Install packages for accessing man and texinfo pages
pacstrap /mnt man-db man-pages texinfo

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Remove the subvolume identification from the subvolume mounted to /
sed -i 's/,subvolid=258,subvol=\/@\/.snapshots\/1\/snapshot//' /mnt/etc/fstab

# Remove rootflags
sed -i 's/rootflags=subvol=${rootsubvol}\s//' /mnt/etc/grub.d/10_linux
sed -i 's/rootflags=subvol=${rootsubvol}\s//' /mnt/etc/grub.d/20_linux_xen

# Davinci Resolve interfaces the ALSA directly, so we need to redirect it to use PulseAudio
echo -e "pcm.!default pulse\nctl.!default pulse" >> /mnt/etc/asound.conf

# Ensure modules are loaded in the correct order to uensure pwmconfig configuration is always up-to-date
echo -e "iwlwifi\nnct6775\nhid_logitech_hidpp" >> /mnt/etc/modules-load.d/hwmon.conf

# execute arch-chroot script
arch-chroot /mnt sh -c "$(curl -fsSL https://raw.github.com/Latinneo/archer/master/bootstrap.sh)"

