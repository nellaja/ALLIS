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

info_print "CPU is $cpu"
sleepy 5
input_print "Microcode is $microcode"
error_print "Microcode Image is $microcode_img"
