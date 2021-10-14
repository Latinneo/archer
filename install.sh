#!/bin/bash

BOOT_MODE=""
SELECTED_BLOCK_DEVICE=""
PARTITIONING_METHOD=""
HOSTNAME="zion"
FULLNAME=""
USER=""
USER_GROUPS=""
SELECTED_SHELL=""
PASSWORD=""

abort() {
    clear
    exit 1
}

detect_boot_mode() {
    if ls /sys/firmware/efi/efivars &> /dev/null; then
        BOOT_MODE="efi"
    else
        BOOT_MODE="bios"
    fi
}

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

select_block_device() {
    # open fd
    exec 3>&1
    local AVAILABLE_BLOCK_DEVICES_RAW=$(lsblk -n -d --output PATH 3>&1 2>&1 1>&3)
    readarray -t AVAILABLE_BLOCK_DEVICES_ARRAY <<<"$AVAILABLE_BLOCK_DEVICES_RAW"
    
    local status="off"
    local AVAILABLE_BLOCK_DEVICES=()   
    local DEFAULT_BLOCK_DEVICE="${AVAILABLE_BLOCK_DEVICES_ARRAY[0]}"                                                                                                                                                                                                                             

    for i in "${!AVAILABLE_BLOCK_DEVICES_ARRAY[@]}"; do
        if [[ "${AVAILABLE_BLOCK_DEVICES_ARRAY[$i]}" == "$DEFAULT_BLOCK_DEVICE" ]]; then
            status="ON"
        else
            status="off"
        fi

        AVAILABLE_BLOCK_DEVICES+=( "$i" "${AVAILABLE_BLOCK_DEVICES_ARRAY[$i]}" $status )
    done

    BLOCK_DEVICE_SELECTION=$(dialog --backtitle "ArchLinux Installer" \
        --title "Device Selection" \
        --radiolist "Select the device where you want to install ArchLinux" 0 40 0 \
        "${AVAILABLE_BLOCK_DEVICES[@]}"  \
    2>&1 1>&3)

    # close fd
    exec 3>&-

    if [ ! -z $BLOCK_DEVICE_SELECTION ]; then
        SELECTED_BLOCK_DEVICE="${AVAILABLE_BLOCK_DEVICES_ARRAY[$BLOCK_DEVICE_SELECTION]}"
    fi
}

select_partitioning_method() {

    # open fd
    exec 3>&1

    # Store data to $VALUES variable
    PARTITIONING_METHOD=$(dialog --backtitle "ArchLinux Installer" \
        --title " Partition disks " \
        --radiolist "Select a partitioning method" 0 0 0 \
        1 "Guided: use entire disk" off \
        2 "Manual: create your own partitions" ON \
    2>&1 1>&3)

    # close fd
    exec 3>&-
}

build_filesystem() {
    # partition disk
    cat $BOOT_MODE.fdisk | sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' | fdisk ${SELECTED_BLOCK_DEVICE}
    
    # format partitions
    if [[ "$BOOT_MODE" == "bios" ]]; then
        echo "${SELECTED_BLOCK_DEVICE}1"
        # if ! mkfs.ext4 ${SELECTED_BLOCK_DEVICE1}1; then
        #     dialog --backtitle "ArchLinux Installer" --title " Build filesystem " --msgbox "mkfs.ext4 ${SELECTED_BLOCK_DEVICE1}1 failed" 6 30
        #     abort
        # fi
    fi

    if [[ "$BOOT_MODE" == "efi" ]]; then
        echo "will do later"
    fi
}

select_partition() {
    # open fd
    exec 3>&1
    AVAILABLE_PARTITIONS_RAW=$(lsblk -n -l -o PATH,PARTTYPENAME,TYPE $SELECTED_BLOCK_DEVICE | grep part | awk '{print substr($0, 0, length($0) - 4)}' 3>&1 2>&1 1>&3)
    readarray -t AVAILABLE_PARTITIONS_ARRAY <<<"$AVAILABLE_PARTITIONS_RAW"
    status="off"
    AVAILABLE_PARTITIONS=()   
    DEFAULT_PARTITION="${AVAILABLE_PARTITIONS_ARRAY[0]}"                                                                                                                                                                                                                             

    for i in "${!AVAILABLE_PARTITIONS_ARRAY[@]}"; do
        if [[ "${AVAILABLE_PARTITIONS_ARRAY[$i]}" == "$DEFAULT_PARTITION" ]]; then
            status="ON"
        else
            status="off"
        fi

        AVAILABLE_PARTITIONS+=( "$i" "${AVAILABLE_PARTITIONS_ARRAY[$i]}" $status )
    done

    PARTITION_SELECTION=$(dialog --backtitle "ArchLinux Installer" \
        --title "Select partition" \
        --radiolist "Select a partition" 0 0 0 \
        "${AVAILABLE_PARTITIONS[@]}"  \
    2>&1 1>&3)

    # close fd
    exec 3>&-

    echo "${AVAILABLE_PARTITIONS_ARRAY[$PARTITION_SELECTION]}"
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
}

detect_boot_mode
echo "Detected boot mode: $BOOT_MODE"

select_block_device
if [ -z "$SELECTED_BLOCK_DEVICE" ]; then
    abort
fi

select_partitioning_method
if [ -z "$PARTITIONING_METHOD" ]; then
    abort
fi

case $PARTITIONING_METHOD in
    1)
        build_filesystem
        ;;
    2)
        clear
        if ! fdisk $SELECTED_BLOCK_DEVICE 2> /dev/null; then
            dialog --backtitle "ArchLinux Installer" --title "Access Denied" --msgbox "You don't have permissions to run fdisk" 6 30
            abort
        fi
        ;;
esac    


# select boot
# select_partition
# get_hostname
# create_user

# echo -e "block device: $SELECTED_BLOCK_DEVICE\nhostname: $HOSTNAME\n\nfull name: $FULLNAME\nuser: $USER\nshell: $SHELL\ngroups: $USER_GROUPS\npassword: $PASSWORD"
