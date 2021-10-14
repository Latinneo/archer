#!/bin/bash
HOSTNAME=""
FULLNAME=""
USER=""
USER_GROUPS=""
SELECTED_SHELL=""
PASSWORD=""

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

get_zoneinfo() {
    echo "TBD"
}

select_shell() {
    # open fd
    exec 3>&1
    AVAILABLE_SHELLS_RAW=$(chsh -l 3>&1 2>&1 1>&3)
    readarray -t AVAILABLE_SHELLS_ARRAY <<<"$AVAILABLE_SHELLS_RAW"
    status="off"
    AVAILABLE_SHELLS=()   
    DEFAULT_SHELL="/bin/bash"                                                                                                                                                                                                                             

    for i in "${!AVAILABLE_SHELLS_ARRAY[@]}"; do
        if [[ "${AVAILABLE_SHELLS_ARRAY[$i]}" == "$DEFAULT_SHELL" ]]; then
            status="ON"
        else
            status="off"
        fi

        AVAILABLE_SHELLS+=( "$i" "${AVAILABLE_SHELLS_ARRAY[$i]}" $status )
    done

    SHELL_SELECTION=$(dialog --backtitle "ArchLinux Installer" \
        --title "Shell Selection" \
        --radiolist "Select your user's shell" 0 0 0 \
        "${AVAILABLE_SHELLS[@]}"  \
    2>&1 1>&3)

    # close fd
    exec 3>&-

    SELECTED_SHELL="${AVAILABLE_SHELLS_ARRAY[$SHELL_SELECTION]}"
}


get_password() {
    # open fd
    exec 3>&1

    # Store data to $VALUES variable
    PASSWORD=$(dialog --ok-label "Submit" \
        --backtitle "Arch Linux Installer" \
        --title "Set User Password" \
        --insecure \
        --clear \
        --passwordbox "Enter password for $USER" 10 30\
    2>&1 1>&3)

    # close fd
    exec 3>&-
}

create_user() {
   
    # open fd
    exec 3>&1

    USER_DETAILS_FORM=$(dialog --ok-label "Submit" \
        --backtitle "Arch Linux Installer" \
        --title "Add User" \
        --form "Create a new user" 0 0 0 \
            "Full name:"        1 1 "$FULLNAME" 1 18 40 0  \
            "Username:"         2 1	"$USER" 	2 18 40 0  \
            "Groups:"           3 1	"$USER_GROUPS"  	3 18 40 0 \
    2>&1 1>&3)

    # close fd
    exec 3>&-

    readarray -t USER_DETAILS <<<"$USER_DETAILS_FORM"
    FULLNAME="${USER_DETAILS[0]}"
    USER="${USER_DETAILS[1]}"
    USER_GROUPS="${USER_DETAILS[2]}"

    select_shell
    get_password

    # create user
    useradd -mG $USER_GROUPS -s $SELECTED_SHELL $USER
    chfn -f "$FULLNAME" $USER
    echo "$USER:$PASSWORD" | chpasswd

    # add user to sudoers
    echo -e "%$USER ALL=(ALL) ALL" > /etc/sudoers.d/1_$USER
}

configure_local_system() {

    get_zoneinfo

     # set time zone
    ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

    # syncrhonize the clock
    hwclock --systohc

    # update the locale
    sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen && locale-gen
    echo LANG=en_US.UTF-8 >> /etc/locale.conf

    # set hostname
    echo "$HOSTNAME" >> /etc/hostname

    # set hosts
    echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" >> /etc/hosts

    # update max user watches & instances
    echo -e "fs.inotify.max_user_watches=524288\nfs.inotify.max_user_instances=524288" >> /etc/sysctl.conf
    sysctl -p -q
}

install_packages() {

    # install reflector
    pacman -S --noconfirm reflector
    sed -i  's/^# --country France,Germany/--country US/g' /etc/xdg/reflector/reflector.conf
    sed -i  's/^--sort age/--sort rate/g' /etc/xdg/reflector/reflector.conf
    sed -i  's/^--latest 5/--latest 3/g' /etc/xdg/reflector/reflector.conf
    echo -e "\n# Only return mirrors that have synchronized in the last 2 hours\n--age 2" >> /etc/xdg/reflector/reflector.conf

    # install shells 
    pacman -S --noconfirm zsh

    # install editors
    pacman -S --noconfirm vim

    # install filesystem packages
    pacman -S --noconfirm btrfs-progs

    # install networking packages
    pacman -S --noconfirm networkmanager networkmanager-openvpn 

    # install bluetooth packages
    pacman -S --noconfirm bluez bluez-utils 

    # install printing support
    pacman -S --noconfirm cups cups-pdf

    # install audio 
    pacman -S --noconfirm pipewire pipewire-alsa pipewire-jack pipewire-media-session pipewire-pulse gst-plugin-pipewire libpulse 

    # install xorg and drivers
    pacman -S --noconfirm  xorg-server xorg-xinit mesa # xf86-video-amdgpu libva-mesa-driver vulkan-radeon 

    # install display manager package
    pacman -S --noconfirm gdm 

    # install desktop packages
    pacman -S --noconfirm gnome gnome-tweaks gnome-software-packagekit-plugin 

    # install browser
    pacman -S --noconfirm firefox 

    # # install development support
    # pacman -S --noconfirm base-devel linux-headers git dotnet-sdk-3.1 aspnet-runtime-3.1 docker docker-compose 

    # install boot loader packages
    # pacman -S --noconfirm os-prober ntfs-3g efibootmgr 
    pacman -S --noconfirm grub 
}

enable_services() {
    systemctl enable NetworkManager
    systemctl enable docker
    systemctl enable bluetooth
    systemctl enable reflector.service
    systemctl enable cups.socket
    systemctl enable gdm
}

install_grub() {
    grub-install --target=i386-pc /dev/vda # x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
}

regenerate_initramfs() {
    # update mkinitcpio.conf
    sed -i 's/^MODULES=()/MODULES=(btrfs)/g' /etc/mkinitcpio.conf

    # regenerate initramfs
    mkinitcpio -p linux
}

get_hostname
configure_local_system
install_packages
create_user
enable_services
install_grub
regenerate_initramfs