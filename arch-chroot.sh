#!/bin/bash
HOSTNAME=""

# open fd
exec 3>&1

get_hostname() {

    # open fd
    exec 3>&1

    # Store data to $VALUES variable
    HOSTNAME=$(dialog --ok-label "Submit" \
        --backtitle "Arch Linux Installer" \
        --title "Hostname" \
        --form "Enter computer hostname" 0 0 0 \
        "Hostname:" 1 1 "$HOSTNAME" 1 18 40 0 \
    2>&1 1>&3)

    # close fd
    exec 3>&-
}

# # set time zone
# ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

# # syncrhonize the clock
# hwclock --systohc

# # update the locale
# sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen && locale-gen
# echo LANG=en_US.UTF-8 >> /etc/locale.conf

# # set hostname
# echo "$HOSTNAME" >> /etc/hostname

# # set hosts
# echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\tzion.localdomain\tzion" >> /etc/hosts

# # install reflector
# pacman -S --noconfirm reflector
# sed -i  's/^# --country France,Germany/--country US/g' /etc/xdg/reflector/reflector.conf
# sed -i  's/^--sort age/--sort rate/g' /etc/xdg/reflector/reflector.conf
# sed -i  's/^--latest 5/--latest 3/g' /etc/xdg/reflector/reflector.conf
# echo -e "\n# Only return mirrors that have synchronized in the last 2 hours\n--age 2" >> /etc/xdg/reflector/reflector.conf

# # install shells 
# pacman -S --noconfirm zsh

# # install editors
# pacman -S --noconfirm vim

# # install filesystem packages
# pacman -S --noconfirm btrfs-progs

# # install networking packages
# pacman -S --noconfirm networkmanager networkmanager-openvpn 

# # install bluetooth packages
# pacman -S --noconfirm bluez bluez-utils 

# # install printing support
# pacman -S --noconfirm cups cups-pdf

# # install audio 
# pacman -S --noconfirm pipewire pipewire-alsa pipewire-jack pipewire-media-session pipewire-pulse gst-plugin-pipewire libpulse 

# # install xorg and drivers
# pacman -S --noconfirm  xorg-server xorg-xinit mesa xf86-video-amdgpu libva-mesa-driver vulkan-radeon 

# # install display manager package
# pacman -S --noconfirm gdm 

# # install desktop packages
# pacman -S --noconfirm gnome gnome-tweaks gnome-software-packagekit-plugin 

# # install browser
# pacman -S --noconfirm firefox 

# # install development support
# pacman -S --noconfirm base-devel linux-headers git dotnet-sdk-3.1 aspnet-runtime-3.1 docker docker-compose 

# # install boot loader packages
# pacman -S --noconfirm os-prober ntfs-3g efibootmgr 
# pacman -S --noconfirm grub 

# # create my user
# useradd -mG wheel,docker -s /usr/bin/zsh $user
# chfn -f "Ariel de Llano" $user
# echo "$user:$password" | chpasswd

# # add my user to sudoers
# echo -e "%$user ALL=(ALL) ALL" > /etc/sudoers.d/1_$user

# # update max user watches & instances
# echo -e "fs.inotify.max_user_watches=524288\nfs.inotify.max_user_instances=524288" >> /etc/sysctl.conf
# sysctl -p -q

# # enable services
# systemctl enable NetworkManager
# systemctl enable docker
# systemctl enable bluetooth
# systemctl enable reflector.service
# systemctl enable cups.socket
# systemctl enable gdm

# # install grub
# grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
# grub-mkconfig -o /boot/grub/grub.cfg

# # update mkinitcpio.conf
# sed -i 's/^MODULES=()/MODULES=(btrfs amdgpu radeon)/g' /etc/mkinitcpio.conf

# # regenerate initramfs
# mkinitcpio -p linux

# # create my user
# useradd -mG wheel,docker -s /usr/bin/zsh $user
# chfn -f "$user_fullname" $user
# echo "$user:$password" | chpasswd

# # add my user to sudoers
# echo -e "%$user ALL=(ALL) ALL" > /etc/sudoers.d/1_$user

# # update max user watches & instances
# echo -e "fs.inotify.max_user_watches=524288\nfs.inotify.max_user_instances=524288" >> /etc/sysctl.conf
# sysctl -p -q

# # enable services
# systemctl enable NetworkManager
# systemctl enable docker
# systemctl enable bluetooth
# systemctl enable reflector.service
# systemctl enable cups.socket
# systemctl enable gdm

# # install grub
# echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
# grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
# grub-mkconfig -o /boot/grub/grub.cfg

# # update mkinitcpio.conf
# sed -i 's/^MODULES=()/MODULES=(btrfs amdgpu radeon)/g' /etc/mkinitcpio.conf

# # regenerate initramfs
# mkinitcpio -p linux 

get_hostname