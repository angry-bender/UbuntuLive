#!/bin/bash


#function to install apps with a clean display
function retryinstall
{
echo -e "[\033[33m-\e[0m] Retrying..."
DEBIAN_FRONTEND=noninteractive apt-get --fix-broken install -yq -o  Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >/dev/null 2>/dev/nul
DEBIAN_FRONTEND=noninteractive apt-get install --fix-missing -yq -o  Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >/dev/null 2>/dev/nul
DEBIAN_FRONTEND=noninteractive apt-get install -yq -o  Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $1 >/dev/null 2>/dev/null && echo -e "[\033[32m*\e[0m]OK" || echo -e "[\033[31m-\e[0m] FAILED"
}
function install
{
echo -n "installing:$1 "
DEBIAN_FRONTEND=noninteractive apt-get install -yq -o  Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $1 >/dev/null 2>/dev/null && echo -e "[\033[32m*\e[0m]OK" || retryinstall $1
}

#function to install with no dependencies
function installnodep
{
echo -n "installing:$1 "
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -yq -o  Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"  $1 >/dev/null 2>/dev/null && echo -e "[\033[32m*\e[0m]OK" || retryinstall $1
}

function exitcheck ()
{
    #Function to check exit codes
    if [[ $1 -ne 0 ]]; then
    echo -e "[\033[31m-\e[0m] FAILED"
    echo -e "[\033[31m-\e[0m] Exiting now"
    exit 1
    else
        echo -e "[\033[32m*\e[0m]OK"
    fi 
}


#Updates apt and include i386 support (Cannot capture APT Exit code... due to 2 exit code (APT Unstable on CLI Warning...))
echo -n "adding:32 bit support "
dpkg --add-architecture i386 1>/dev/null
exitcheck "$?"
echo -n "updating:Ubuntu package lists "
apt update >/dev/null 2>&1 
exitcheck "$?"
install software-properties-common
echo -n "adding:Software Properties Common PPA "
add-apt-repository --yes ppa:graphics-drivers/ppa >/dev/null 2>&1
exitcheck "$?"
echo -n "updating:APT config "
apt update >/dev/null 2>&1
exitcheck "$?"

#Install Live environment
install ubuntu-standard 
install casper 
install lupin-casper
install discover 
install laptop-detect 
install os-prober
install linux-firmware
install linux-generic 
install xserver-xorg 
install xserver-xorg-video-all 
install xinit 
install gdm3

# Install nvidia drivers if required. Only one NVIDIA driver can be installed at a time, so comment out change to NVIDIA390 or 340 for older cards

installnodep nvidia-driver-410 
installnodep libnvidia-gl-410
installnodep nvidia-utils-410 
installnodep xserver-xorg-video-nvidia-410 
installnodep libnvidia-cfg1-410 libnvidia-ifr1-410 
installnodep libnvidia-decode-410 
installnodep libnvidia-encode-410

#Customise Ubuntu and bootscreen
sudo chmod -x /etc/update-motd.d/*
sudo chmod +x /etc/update-motd.d/01-custom


#Cleanup old Kernel Files
current_kernel="$(uname -r | sed 's/\(.*\)-\([^0-9]\+\)/\1/')"
current_ver=${current_kernel/%-generic}

echo "Running kernel version is: ${current_kernel}"
# uname -a

function xpkg_list() {
dpkg -l 'linux-*' | sed '/^ii/!d;/linux-libc-dev/d;/'${current_ver}'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d'
}

echo "The following (unused) KERNEL packages will be removed:"
xpkg_list

xpkg_list | xargs sudo apt-get -y purge 1>/dev/null && echo -e "[\033[32m*\e[0m]Removed"