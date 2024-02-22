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

# Font package group (imports from fonts_pkg)
curl -Os https://raw.githubusercontent.com/nellaja/ALLIS/main/fonts_pkg
mapfile -t fonts_pkgs < fonts_pkg

# Essentials package group (imports from essentials_pkg file)
curl -Os https://raw.githubusercontent.com/nellaja/ALLIS/main/essentials_pkg
mapfile -t essentials_pkgs < essentials_pkg

# Sway package group (imports from sway_pkg file)
curl -Os https://raw.githubusercontent.com/nellaja/ALLIS/main/sway_pkg
mapfile -t sway_pkgs < sway_pkg

# Extras package group (imports from extras_pkg file)
curl -Os https://raw.githubusercontent.com/nellaja/ALLIS/main/extras_pkg
mapfile -t extras_pkgs < extras_pkg

# AUR package group (imports from aur_pkg file)
curl -Os https://raw.githubusercontent.com/nellaja/ALLIS/main/aur_pkg
mapfile -t aur_pkgs < aur_pkg

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
        info_print "Checking available logical sector size options for $device . . . ."
        nvme id-ns -H "/dev/$device" | grep "Relative Performance"
        input_print "Is the 'in use' format labeled as 'Best' [y/N] . . . .  "
        read -r nvme_response
        if ! [[ "${nvme_response,,}" =~ ^(yes|y)$ ]]; then
            input_print "To format $device, enter the number shown after 'LBA Format' associated with 'Best' performance    "
            read lba_number
            info_print "Formatting $device to new logical sector size . . . ."
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
    sgdisk -Z "/dev/$device"
    wipefs --all --force "/dev/$device"
    sleepy 2

    info_print "Partitioning $device . . . ."
    sgdisk -o "/dev/$device"
    sgdisk -n 0:0:+1G -t 0:ef00 "/dev/$device"
    sgdisk -n 0:0:0 -t 0:8304 "/dev/$device"
    
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
    mkfs.ext4 -FF "/dev/$rootdev"
    sleepy 2

    info_print "Formatting the boot partition as fat32 . . . ."
    mkfs.fat -F 32 "/dev/$bootdev"
    sleepy 2

    # Mount the partitions
    info_print "Mounting the boot and root partitions . . . ."
    mount "/dev/$rootdev" /mnt
    mount --mkdir "/dev/$bootdev" /mnt/boot
    sleepy 3
}


# ------------------------------------------------------------------------------
# Install Base System Function
# ------------------------------------------------------------------------------i

# Installation of the necessary packages for a functioning base system
install_base() {
    clear

    # Update the package list for the base system to include the correct microcode
    base_system+=("$microcode")

    # Pacstrap install the base system
    info_print "Beginning install of the base system packages . . . ."
    sleepy 1
    info_print "An $cpu CPU has been detected; the $cpu microcode will be installed."
    sleepy 2
    pacstrap -K /mnt "${base_system[@]}"
    info_print "Base system installed . . . ."

    sleepy 3
}


# ------------------------------------------------------------------------------
# Set System Time Zone Function
# ------------------------------------------------------------------------------

# Set the system timezone
set_tz() {
    clear
    
    info_print "Setting the timezone to $timezone . . . ."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc

    sleepy 3
}


# ------------------------------------------------------------------------------
# Localization & Virtual Console Function
# ------------------------------------------------------------------------------

# Sets the locale and the keymap and font for the virtual console
set_locale() {
    clear
    
    info_print "Setting locale to $locale . . . ."
    sed -i "s/#$locale/$locale/" /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$locale" > /mnt/etc/locale.conf
    sleepy 2
    
    info_print "Configuring vconsole . . . ."
    echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf
    echo "FONT=$font" >> /mnt/etc/vconsole.conf
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# Network Configuration Function
# ------------------------------------------------------------------------------

# Configures the network files and enables NetworkManager
network_config() {
    clear

    info_print "Setting the hostname to $hostname . . . ."
    echo "$hostname" > /mnt/etc/hostname
    sleepy 2

    info_print "Creating the /etc/hosts file . . . ."
cat > /mnt/etc/hosts <<EOF
127.0.0.1      localhost
::1            localhost
127.0.1.1      $hostname.localdomain     $hostname
EOF
    sleepy 2

    info_print "Configuring NetworkManager . . . ."
cat > /mnt/etc/NetworkManager/conf.d/no-systemd-resolved.conf <<EOF
[main]
systemd-resolved=false
EOF
    sleepy 2
        
    info_print "Enabling NetworkManager service . . . ."
    arch-chroot /mnt systemctl enable NetworkManager

    sleepy 3
}


# ------------------------------------------------------------------------------
# Bootloader Configuration Function
# ------------------------------------------------------------------------------

# Configure the bootloader
bootloader_config() {
    clear

    info_print "Installing systemd-boot . . . ."
    arch-chroot /mnt systemd-machine-id-setup
    arch-chroot /mnt bootctl install
    sleepy 2
    
    info_print "Configuring systemd-boot . . . ."
cat > /mnt/boot/loader/loader.conf <<EOF
default  arch-linux.conf
timeout  3
console-mode max
editor   no
EOF

cat > /mnt/boot/loader/entries/arch-linux.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /$microcode_img
initrd /initramfs-linux.img
options zswap.enabled=0 rw quiet
EOF

cat > /mnt/boot/loader/entries/arch-linux-fallback.conf <<EOF
title Arch Linux (fallback)
linux /vmlinuz-linux
initrd /$microcode_img
initrd /initramfs-linux-fallback.img
options zswap.enabled=0 rw quiet
EOF

cat > /mnt/boot/loader/entries/arch-linux-lts.conf <<EOF
title Arch Linux LTS
linux /vmlinuz-linux-lts
initrd /$microcode_img
initrd /initramfs-linux-lts.img
options zswap.enabled=0 rw quiet
EOF

    sleepy 3
}


# ------------------------------------------------------------------------------
# Pacman Configuration Function
# ------------------------------------------------------------------------------

# Configure pacman
pacman_config() {
    clear

    info_print "Configuring pacman . . . ."
    cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
    sed -i '/Misc options/a \ILoveCandy' /mnt/etc/pacman.conf
    sed -i 's/#UseSyslog/UseSyslog/' /mnt/etc/pacman.conf
    sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
    sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /mnt/etc/pacman.conf
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /mnt/etc/pacman.conf
    sed -i '/#\[multilib\]/a \Include = etc/pacman.d/mirrorlist' /mnt/etc/pacman.conf
    sed -i 's/#\[multilib\]/\[multilib\]/' /mnt/etc/pacman.conf

    sleepy 3
}


# ------------------------------------------------------------------------------
# Install Display Drivers Function
# ------------------------------------------------------------------------------

# Install the appropriate display drivers based on the provided gpu type
install_display() {
    clear
    
    if [ "$gpu" == "AMD" ] ; then
        info_print "Installing display drivers for an AMD GPU . . . ."
        sleepy 2
        arch-chroot /mnt pacman -S --needed --noconfirm "${amd_graphics[@]}" 
        arch-chroot /mnt pacman -S --needed --noconfirm "${amd_graphics_multilib[@]}"
    elif [ "$gpu" == "Intel" ] ; then
        info_print "Installing display drivers for an Intel GPU . . . ."
        sleepy 2
        arch-chroot /mnt pacman -S --needed --noconfirm "${intel_graphics[@]}"
        arch-chroot /mnt pacman -S --needed --noconfirm "${intel_graphics_multilib[@]}"
    else
        error_print "An unsupported GPU manufacturer or no GPU manufacturer has been input by the user."
        error_print "No display drivers will be installed at this time. User to manually install post-script completion."
    fi

    sleepy 3
}


# ------------------------------------------------------------------------------
# Install Audio Drivers Function
# ------------------------------------------------------------------------------

# Installs any necessary audio firmware and installs the pipewire packages
install_audio() {
    clear
    
    awk '{print $1}' /proc/modules | grep -c snd_sof | read count_mod
    if [ $count_mod != "0" ] ; then 
        info_print "The sof-firmware package is required for your system. Installing now . . . ."
        sleepy 1
        arch-chroot /mnt pacman -S --needed --noconfirm sof-firmware
    fi
    sleepy 2

    for x in "${alsa_array[@]}" ; do
        awk '{print $1}' /proc/modules | grep -c "$x" | read count_mod2
        if [ $count_mod2 != "0" ] ; then
            info_print "The alsa-firmware package is required for your system. Installing now . . . ."
            sleepy 1
            arch-chroot /mnt pacman -S --needed --noconfirm alsa-firmware
            sleepy 2
            break 
        fi
    done 

    clear
    info_print "Installing pipewire packages . . . ."
    sleepy 2
    arch-chroot /mnt  pacman -S --needed --noconfirm "${pipewire_pkgs[@]}"
    sleepy 3
}


# ------------------------------------------------------------------------------
# AUR Helper Installation Function
# ------------------------------------------------------------------------------

# Installs the preferred AUR Helper
install_aur() {
    clear

    info_print "Installing AUR helper ($aurhelper) . . . ."
    arch-chroot /mnt git clone "https://aur.archlinux.org/$aurhelper-bin.git"
    arch-chroot /mnt/"$aurhelper-bin" makepkg --noconfirm -si
    arch-chroot /mnt rm -rf "$aurhelper-bin"     
    sleepy 3

    clear
    
    info_print "Installing AUR packages . . . ."
    sleepy 2
    arch-chroot /mnt "$aurhelper" -S --needed --noconfirm "${aur_pkgs[@]}"
    sleepy 3     
}


# ------------------------------------------------------------------------------
# ZRAM Configuration Function
# ------------------------------------------------------------------------------

# Configure and optimize ZRAM
zram_config() {
    clear

    info_print "Configuring ZRAM . . . ."
cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
    sleepy 2

    info_print "Optimizing ZRAM . . . ."
cat > /mnt/etc/sysctl.d/99-vm-zram-parameters.conf <<EOF
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

    sleepy 3
}


# ------------------------------------------------------------------------------
# Miscellaneous Configuration Function
# ------------------------------------------------------------------------------

# Configures miscellaneous files associated with the installed essential packages
misc_config() {
    clear

    info_print "Configuring logrotate.conf . . . ."
    sed -i 's/#compress/compress/' /mnt/etc/logrotate.conf
    sleepy 2

    info_print "Configuring nsswitch.conf . . . ."
    sed -i 's/mymachines/mymachines mdns_minimal [NOTFOUND=return]/' /mnt/etc/nsswitch.conf
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# mkinitcpio Configuration Function
# ------------------------------------------------------------------------------

# Configure and regenerate mkinitcpio
mkinit_config() {
    clear
    
    info_print "Configuring mkinitcpio . . . ."
    cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.bak
    sed -i "s/$hooks_old/$hooks_new/" /mnt/etc/mkinitcpio.conf
    sleepy 2

    info_print "Regenerating initramfs files . . . ."
    arch-chroot /mnt mkinitcpio -P
    sleepy 3
}


# ------------------------------------------------------------------------------
# Create Main User Function
# ------------------------------------------------------------------------------

# Create the main user and configure sudo rights
main_user() {
    clear

    info_print "Configuring sudo rights . . . ."
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    echo "Defaults passwd_timeout=0" > /mnt/etc/sudoers.d/defaults
    echo "Defaults insults" >> /mnt/etc/sudoers.d/defaults
    sleepy 2

    info_print "Hardening log-in protections . . . ."
    echo "auth optional pam_faildelay.so delay=4000000" >> /mnt/etc/pam.d/system-login
    sleepy 2
    
    info_print "Adding the user $username to the system with root privilege . . . ."
    arch-chroot /mnt useradd -m -G wheel "$username"
    sleepy 2
    
    input_print "Set the user password for $username . . . ."
    arch-chroot /mnt passwd "$username"
    
    sleepy 3
}


# ------------------------------------------------------------------------------
# Enable System Services Function
# ------------------------------------------------------------------------------

# Enables system services, except for NetworkManager which was enabled previously
enable_services() {
    clear

    info_print "Enabling system services . . . ."
    arch-chroot /mnt systemctl enable "${arch_services[@]}"
    sleepy 2

    info_print "Enabling system timers . . . ."
    arch-chroot /mnt systemctl enable "${arch_timers[@]}"
    sleepy 2

    info_print "Enabling pipewire services . . . ."
    arch-chroot /mnt systemctl --user -M $username@ enable pipewire.socket pipewire-pulse.socket wireplumber
    sleepy 2
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
clear
info_print "Updating mirrorlist . . . ."
cp mirrors /etc/pacman.d/mirrorlist
sleepy 3

# Install base system
install_base

# Generate fstab
clear
info_print "Generating fstab . . . ."
genfstab -U /mnt >> /mnt/etc/fstab
sleepy 3

# Set timezone
set_tz

# Localization & virtual console configuration
set_locale

# Network configuration
network_config

# Bootloader configuration
bootloader_config

# Pacman configuration
pacman_config

# System update
clear
info_print "Due to pacman config changes, completing a full system update . . . ."
sleepy 2
arch-chroot /mnt pacman -Syyu --noconfirm
sleepy 3

# Install font packages
clear
info_print "Installing fonts . . . ."
sleepy 2
arch-chroot /mnt pacman -S --needed --noconfirm "${fonts_pkgs[@]}"
sleepy 3

# Install additional system essential packages
clear
info_print "Installing additional essential system packages . . . ."
sleepy 2
arch-chroot /mnt pacman -S --needed --noconfirm "${essentials_pkgs[@]}"
sleepy 3

# Install display drivers
install_display

# Install audio drivers
install_audio

# Install sway packages
clear
info_print "Installing Sway packages . . . ."
sleepy 2
arch-chroot /mnt pacman -S --needed --noconfirm "${sway_pkgs[@]}"
sleepy 3

# Install additional extra packages
clear
info_print "Installing extra, user-preferred packages . . . ."
sleepy 2
arch-chroot /mnt pacman -S --needed --noconfirm "${extras_pkgs[@]}"
sleepy 3

# Install AUR Helper and AUR packages
if [ -n "$aurhelper" ] ; then
    install_aur
fi

# zram configuration
zram_config

# Miscellaneous configuration
misc_config

# mkinitcpio configuration
mkinit_config

# Root password
clear
input_print "Set the ROOT password . . . ." 
arch-chroot /mnt passwd
sleepy 1

# Create main user
main_user

# Enable Services
enable_services

# Finish base install
clear
info_print "Installation complete. The system will automatically shutdown now."
sleepy 1
info_print "After shutdown, remove the USB drive, turn on the system, and login as the main user."
sleepy 1
info_print "If main user log-in works, it is recommended to disable root password with 'passwd --lock root'"
sleepy 3

umount -R /mnt
shutdown now
