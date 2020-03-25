#!/bin/bash
# use case ./build.sh

#Variables
ARCH="amd64"
RELEASE="bionic"
STARTDIR=$(dirname "$0") 
UBUNTUDIR=${STARTDIR}/..
TMPDIR="${STARTDIR}/work"
WKDIR="${TMPDIR}/chroot"
BLDFL="${STARTDIR}/buildfiles"

function cleanup() {
    # clean up our temp folder
    sudo rm -rf ./work
}

#Functions for progress Spinner for long running commands
    function shutdown() {
        tput cnorm # reset cursor
    }
        trap shutdown EXIT

    function cursorBack() {
        echo -en "\033[$1D"
    }    
    function spinner() {
        # make sure we use non-unicode character type locale 
        # (that way it works for any locale as long as the font supports the characters)
        local LC_CTYPE=C

        local pid=$1 # Process Id of the previous running command

        case $(($RANDOM % 1)) in
        0)
            local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
            local charwidth=3
            ;;
        esac

        local i=0
        tput civis # cursor invisible
        while kill -0 $pid 2>/dev/null; do
            local i=$(((i + $charwidth) % ${#spin}))
            echo -n "   "
            printf "\e[1;33m%-6s\e[m" "${spin:$i:$charwidth}"
            echo -n ""

            cursorBack 7
            sleep .1
        done
        tput cnorm
        wait $pid # capture exit code
        return $?
    }



function buildubuntu() {
    # create our working folders
    mkdir work
    TMPDIR=work
    #End Temp
    chmod 755 "${TMPDIR}"
   
    
    #Downloads and creates custom ubuntu distro
    echo -n "Downloading and installing ubuntu base chroot, this may take some time"
    debootstrap --arch=$ARCH $RELEASE $TMPDIR/chroot 1>/dev/null & pid=$!
    spinner $pid
    if [[ $? -ne 0 ]]; then
        echo -e "[\033[31m-\e[0m] FAILED"
        echo "Exiting now"
        exit 1
    else
        echo -e "[\033[32m*\e[0m]OK"
    fi 
  
    
    #Copies System Files so you can get internet within chroot sed is used for futureproofing
    cp  /etc/hosts ${WKDIR}/etc/hosts
    cp  -r /etc/resolvconf/* ${WKDIR}/etc/resolvconf/
    sudo cp  /etc/resolv.conf ${WKDIR}/etc/resolv.conf
    
    #Copies binaries and scripts into the chroot environment
    cp ${UBUNTUDIR}/ubuntu-live ${WKDIR}/usr/bin/ubuntu-live
    chmod 755 ${WKDIR}/usr/bin/ubuntu-live
    cp ${BLDFL}/setup.sh ${WKDIR}/tmp/
    chmod 775 ${WKDIR}/tmp/setup.sh
 
              
    # Set hostname
    echo "ubuntu-live-live" | sudo tee ${WKDIR}/etc/hostname 
    echo "127.0.0.1 ubuntu-live-live" | sudo tee ${WKDIR}/etc/hosts
    sleep 5
}

function buildenv() {
    #Chroot into build environment (Output cannot be suppressed)
    sudo chroot ${WKDIR} << "EOT"
    mount none -t proc /proc
    mount none -t sysfs /sys
    mount none -t devpts /dev/pts
    export HOME=/root
    export LC_ALL=C

    #Run setup script

    /tmp/setup.sh

    #Cleanup chroot environment and remove desktop
    apt-get autoremove
    apt-get clean
    rm -rf /tmp/*
    rm /etc/resolv.conf

    umount /proc
    umount /sys
    umount /dev
    #Sometimes the above umount is not working
    umount -lf /proc
    umount -lf /sys
    umount -lf /dev

    #exit the chroot environment
    exit
    #!!!!EOT CANNOT BE INDENTED!!!!
EOT
    
    #Ensure Dev/pts is unmounted
    
    umount ${WKDIR}/dev/pts
}

function mkboot() {
       
    #Sets Autologin
    #autologin.conf is a script to enable auto login on tty1 on boot
    sudo mkdir -pv ${WKDIR}/etc/systemd/system/getty@tty1.service.d
    sudo cp ${BLDFL}/autologin.conf ${WKDIR}/etc/systemd/system/getty@tty1.service.d/
   
}

function mkiso() {
    
    #Attempts to create new ISO Image
    mkdir -p ${TMPDIR}/image/{casper,isolinux,install}
    sudo cp ${WKDIR}/boot/vmlinuz-* ${TMPDIR}/image/casper/vmlinuz
    sudo cp ${WKDIR}/boot/initrd.img* ${TMPDIR}/image/casper/initrd.lz
    cp ${BLDFL}/grub.cfg ${TMPDIR}/image/isolinux/grub.cfg


    #Compressess the Source Ubuntu Chroot into the image/boot file
    echo -n "Compressing chroot filesystem: "
    sudo mksquashfs ${TMPDIR}/chroot ${TMPDIR}/image/casper/filesystem.squashfs -e ${WKDIR}/boot 1>/dev/null & pid=$!
    spinner $pid
    if [[ $? -ne 0 ]]; then
        echo -e "[\033[31m-\e[0m] FAILED"
        echo "Exiting now"
        exit 1
    else
        echo -e "[\033[32m*\e[0m]OK"
    fi 

    # Creates ISO and image directories
    mkdir -p ${TMPDIR}/image/{casper,isolinux,install}
    sudo cp ${WKDIR}/boot/vmlinuz-* ${TMPDIR}/image/casper/vmlinuz
    sudo cp ${WKDIR}/boot/initrd.img* ${TMPDIR}/image/casper/initrd.lz
    cp /usr/lib/ISOLINUX/isolinux.bin ${TMPDIR}/image/isolinux
    cp /usr/lib/syslinux/modules/bios/* ${TMPDIR}/image/isolinux
    cp ${BLDFL}/isolinux.cfg ${TMPDIR}/image/isolinux/isolinux.cfg

    # Attempts to create UEFI Image
    grub-mkstandalone \
   --format=x86_64-efi \
   --output=${TMPDIR}/image/isolinux/bootx64.efi \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=${TMPDIR}/image/isolinux/grub.cfg"
       
    dd if=/dev/zero of=${TMPDIR}/image/isolinux/efiboot.img bs=1M count=10 && \
    sudo mkfs.vfat ${TMPDIR}/image/isolinux/efiboot.img && \
    mmd -i ${TMPDIR}/image/isolinux/efiboot.img efi efi/boot && \
    mcopy -i ${TMPDIR}/image/isolinux/efiboot.img ${TMPDIR}/image/isolinux/bootx64.efi ::efi/boot/

    #Copies the required files for future USB Builds if required and builds the ISO Image
    cp ${BLDFL}/README.diskdefines ${TMPDIR}/image/
    touch ${TMPDIR}/image/ubuntu
    mkdir ${TMPDIR}/image/.disk >/dev/null 2>&1
    touch ${TMPDIR}/image/.disk/base_installable
    echo "full_cd/single" > ${TMPDIR}/image/.disk/cd_type
    echo "ubuntu-live V2.0" > ${TMPDIR}/image/.disk/info
    echo "See Objective Build Documentation for Release Notes" > ${TMPDIR}/image/isolinux/release_notes_url
    
    #Makes the Source ISO File
    cd ${TMPDIR}/image/
    sudo xorriso \
    --stdio_sync on \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c isolinux/boot.cat -b isolinux/isolinux.bin \
    -volid "ubuntu-liveV2.0" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
    -e EFI/efiboot.img \
    -no-emul-boot \
    -append_partition 2 0xef isolinux/efiboot.img \
    -isohybrid-gpt-basdat \
    -output "../../../ubuntu-liveV2.0.iso" \
    -graft-points \
      "." \
      /boot/grub/bios.img=isolinux/bios.img \
      /EFI/efiboot.img=isolinux/efiboot.img 

    # Print Completion message
    echo -e "[\033[32mubuntu-live Build Complete\e[0m] "
 
}

main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run with sudo" 
        exit 1
    fi

    if [ -f /var/run/reboot-required ]; then
        echo 'reboot required Please reboot prior to proceeding' && exit 0
        end
    else
	cleanup
    buildubuntu
    buildenv
    mkboot
    mkiso
	cleanup	
    fi
}

main
