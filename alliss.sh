#!/usr/bin/env bash

set -e
shopt -s extglob
shopt -s lastpipe

# Cleaning the TTY
clear


# ------------------------------------------------------------------------------
# Variable Definitions - User Defined
# ------------------------------------------------------------------------------

rest=1                         # Scripting variable to control pause delay (set to 0 for no pauses; set to 1 for comfortable pauses)
keymap="us"                    # Console keymap setting (localectl list-keymaps)
font="ter-128b"                # Console font (ls -a /usr/share/kbd/consolefonts)
timezone="America/New_York"    # Location timezone
locale="en_US.UTF-8"           # Locale and language variable
aurhelper="paru"               # AUR helper

# Base system package group
base_system=(base base-devel linux linux-lts linux-firmware vim terminus-font git networkmanager)

# AMD graphics drivers
amd_graphics=(mesa vulkan-radeon vulkan-icd-loader libva-mesa-driver)
amd_graphics_multilib=(lib32-mesa lib32-vulkan-radeon lib32-vulkan-icd-loader lib32-libva-mesa-driver)

# Intel graphics drivers
intel_graphics=(mesa vulkan-intel vulkan-icd-loader intel-media-driver)
intel_graphics_multilib=(lib32-mesa lib32-vulkan-intel lib32-vulkan-icd-loader)

# Pipewire package group
pipewire_pkgs=(pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire libpulse)

# List of services and timers that need to be enabled
arch_services=(avahi-daemon bluetooth cups firewalld ly systemd-boot-update systemd-timesyncd)
arch_timers=(archlinux-keyring-wkd-sync.timer fstrim.timer logrotate.timer)

# mkinitcpio hooks
hooks_old="HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)"
hooks_new="HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)"

# Array of modules to check if they exist on the system to determine if alsa-firmware package is required
alsa_array=(snd_asihpi snd_cs46xx snd_darla20 snd_darla24 snd_echo3g snd_emu10k1 snd_gina20 snd_gina24 snd_hda_codec_ca0132 snd_hdsp snd_indigo snd_indigodj snd_indigodjx snd_indigoio snd_indigoiox snd_layla20 snd_layla24 snd_mia snd_mixart snd_mona snd_pcxhr snd_vx_lib)


# ------------------------------------------------------------------------------
# Variable Definitions - Imported From Cloned ALLIS Repository
# ------------------------------------------------------------------------------

# Mirror list import (file name will be "mirrors")
curl -Os https://raw.githubusercontent.com/nellaja/ALLIS/main/mirrors


# ------------------------------------------------------------------------------
# Variable Definitions - Auto Defined
# ------------------------------------------------------------------------------

# Determine the CPU manufacturer and assign corresponding microcode values
cpu=$(lscpu | grep "Vendor ID:")

if [[ "$cpu" == *"AuthenticAMD"* ]] ; then
    cpu="AMD"
    microcode="amd-ucode"
    microcode_img="amd-ucode.img"
else
    cpu="Intel"
    microcode="intel-ucode"
    microcode_img="intel-ucode.img"
fi


# ------------------------------------------------------------------------------
# Pretty Print Functions
# ------------------------------------------------------------------------------

# Cosmetics (colours for text in the pretty print functions)
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print for general information
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for user input
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Pretty print to alert user of bad input
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}


# ------------------------------------------------------------------------------
# Sleep Time Function
# -----------------------------------------------------------------------------y-

# Sets sleep time to allow for pauses (or no pauses) during the script to let the user follow along
sleepy() {
    let "t = $1 * $rest"
    sleep $t
}


# ------------------------------------------------------------------------------
# Internet Connection Functions
# ------------------------------------------------------------------------------

# Exit the script if there is no internet connection
not_connected() {
    sleepy 1
    
    error_print "No network connection!!!  Exiting now."
    sleepy 1
    error_print "Your entire life has been a mathematical error."
    sleepy 1
    exit 1
}

# Check for working internet connection
check_connection() {
    clear
    
    info_print "Trying to ping archlinux.org . . . ."
    $(ping -c 3 archlinux.org &>/dev/null) ||  not_connected

    info_print "Connection good!"
    sleepy 1
    info_print "Well done, android."
    sleepy 2
}


# ------------------------------------------------------------------------------
# User Input Functions
# ------------------------------------------------------------------------------

# User input function for selection of terminal font and gpu manufacturer

user_input() {
    clear

    # Set terminal font size
    info_print "Setting the default font to $font . . . ."
    setfont "$font"
    sleepy 1

    info_print "If default $font is too big or too small, select a new size (sorted smallest to biggest); select DONE when finished . . . ."
    select font_sel in ter-118b ter-120b ter-122b ter-124b ter-128b ter-132b DONE ;
    do
        case $font_sel in
            DONE)
                info_print "$font font has been selected and set . . . ."
                sleepy 2
                break
                ;;
            *)
                font="$font_sel"
                info_print "Setting the font to $font . . . ."
                setfont "$font"
                sleepy 1
                info_print "Select different font size or select DONE to complete selection of $font . . . ."
                ;;
        esac
    done

    clear
    
    # Input GPU manufacturer (nvidia not supported)
    info_print "Select the manufacturer of your GPU . . . ."
    select gpu in AMD Intel SKIP ;
    do
        case $gpu in
            AMD)
                info_print "AMD graphics drivers will be installed . . . ."
                sleepy 2
                break
                ;;
            Intel)
                info_print "Intel graphics drivers will be installed . . . ."
                sleepy 2
                break
                ;;
            *)
                info_print "No graphics drivers will be installed . . . ."
                sleepy 2
                break
                ;;
        esac
    done

    clear

    # Input block device on which Arch will be installed
    info_print "The recognized block devices are as follows . . . ."
    lsblk -d
    sleepy 2

    while true ; do 
        input_print "Enter the name of the block device for the installation (sdX or nvmeYn1) . . . .  "
        read device

        lsblk -d | grep -c "$device" | read count_device
        if [ $count_device != "0" ] ; then
            info_print "Arch Linux will be installed on $device . . . ."
            sleepy 2
            break 
        else
            error_print "$device does not appear to be a recognized block device; try again . . . ."
            sleepy 1
        fi
    done

    # Define the partition numbers for boot and root partitions based on the provided device name
    if [ "${device::4}" == "nvme" ] ; then
        bootdev="${device}p1"
        rootdev="${device}p2"
    else
        bootdev="${device}1"
        rootdev="${device}2"
    fi

    clear

    # Enter hostname for the computer
    input_print "Enter a hostname for this computer . . . .  "
    read hostname
    sleepy 1

    clear

    # Enter main user name
    input_print "Enter a username for the main non-root user . . . .  "
    read username

    sleepy 1
}


# ------------------------------------------------------------------------------
# Terminal Initialization Function
# ------------------------------------------------------------------------------

# Initializes the console keymap (user defined variables) and the system time
terminal_init() {
    clear
    
    info_print "Changing console keyboard layout to $keymap . . . ."
    loadkeys "$keymap"
    sleepy 2
      
    info_print "Configuring system date and time . . . ."
    timedatectl set-ntp true
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# Partition Disk Function
# ------------------------------------------------------------------------------

# Partitions the device name selected by the user
part_disk() {
    clear
    
    info_print "Arch Linux will be installed on the following disk: $device"
    sleepy 2
    
     # If $device is an nvme device, check status of its logical sector size
    if [ "${device::4}" == "nvme" ] ; then
        input_print "Checking available logical sector size options for $device . . . ."
        nvme id-ns -H "/dev/$device" | grep "Relative Performance"
        input_print "Is the 'in use' format labeled as 'Best' [y/N] . . . .  "
        read -r nvme_response
        if ! [[ "${nvme_response,,}" =~ ^(yes|y)$ ]]; then
            input_print "To format $device, enter the number shown after 'LBA Format' associated with 'Best' performance    "
            read lba_number
            input_print "Formatting $device to new logical sector size . . . ."
            nvme format --lbaf="$lba_number" --force "/dev/$device"
        fi
    fi

    clear

    input_print "This operation will wipe and delete $device.  Do you agree to proceed [y/N] . . . .  "
    read -r disk_response
    if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]] ; then
        error_print "Quitting . . . ."
        sleepy 1
        error_print "Nice job breaking it. Hero."
        exit
    fi

    info_print "Wiping $device . . . ."
    #sgdisk -Z "/dev/$device"
    #wipefs --all --force "/dev/$device"
    sleepy 2

    info_print "Partitioning $device . . . ."
    #sgdisk -o "/dev/$device"
    #sgdisk -n 0:0:+1G -t 0:ef00 "/dev/$device"
    #sgdisk -n 0:0:0 -t 0:8304 "/dev/$device"
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# Format & Mount Partitions Function
# ------------------------------------------------------------------------------i

# Formats the partitions and mounts them
format_mount() {
    clear
    
    # Format the partitions
    info_print "Formatting the root partition as ext4 . . . ."
    #mkfs.ext4 -FF "/dev/$rootdev"
    sleepy 2

    info_print "Formatting the boot partition as fat32 . . . ."
    #mkfs.fat -F 32 "/dev/$bootdev"
    sleepy 2

    # Mount the partitions
    info_print "Mounting the boot and root partitions . . . ."
    #mount "/dev/$rootdev" /mnt
    #mount --mkdir "/dev/$bootdev" /mnt/boot
    sleepy 3
}


# ------------------------------------------------------------------------------
# Begin Install
# ------------------------------------------------------------------------------

clear

# Welcome message
info_print "Hello and, again, welcome to the Aperture Science computer-aided enrichment center."
sleepy 2
info_print "Beginning Arch Linux installation . . . ."
sleepy 2

# Check for working internet connection; will exit script if there is no connection
check_connection

# Obtain user input
user_input

# Initialize tty terminal and system clock
terminal_init

# Partition the disk
part_disk

# Format and mount the partitions
format_mount

# Update mirrorlist
info_print "Updating mirrorlist . . . ."
cp mirrors /etc/pacman.d/mirrorlist
sleepy 3


