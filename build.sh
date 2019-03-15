#!/bin/bash
# use case ./build.sh 

#Variables
ARCH=amd64
RELEASE=bionic
TMPDIR=work
WKDIR=${TMPDIR}/chroot
BLDFL=buildfiles/

function cleanup() {
    # clean up our temp folder
    sudo rm -rf "${TMPDIR}"
    sudo rm -rf "image"
}

function buildubuntu() {

    # create our working folders
    mkdir work
    TMPDIR=work
    #End Temp
    chmod 755 "${TMPDIR}"
    cd ${TMPDIR}

    #Downloads and creates custom ubuntu distro
    debootstrap --arch=$ARCH $RELEASE chroot
    cd ..

    #Copies System Files so you can get internet within chroot sed is used for futureproofing
    cp -v /etc/hosts ${WKDIR}/etc/hosts
    cp -v ${BLDFL}/sources.list ${WKDIR}/etc/apt/sources.list
    cp -v -r /etc/resolvconf/* ${WKDIR}/etc/resolvconf/
    sudo cp -v /etc/resolv.conf ${WKDIR}/etc/resolv.conf

    # Set hostname
    echo "ubuntu-live" | sudo tee ${WKDIR}/etc/hostname
    echo "127.0.0.1 ubuntu-live" | sudo tee ${WKDIR}/etc/hosts
    sleep 5
}

function buildenv() {
    #Chroot into build environment   
    sudo chroot ${WKDIR} << "EOT"
    mount none -t proc /proc
    mount none -t sysfs /sys
    mount none -t devpts /dev/pts
    export HOME=/root
    export LC_ALL=C

    #Updates apt and include i386 support
    dpkg --add-architecture i386
    apt update
    apt-get install --yes software-properties-common
    add-apt-repository ppa:graphics-drivers/ppa -y
    apt update


    #Install Live environment
    DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ubuntu-standard casper lupin-casper
    DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" discover laptop-detect os-prober
    DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" linux-generic xserver-xorg xserver-xorg-video-all
  
    #Insert any further packages here
    #apt-get install --yes <packagename>
    #DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" <Packagename>
    #dpkg -i <packagename>

    #Cleanup chroot environment and remove desktop (Nvidia Package installs it)
    apt-get autoremove
    apt-get clean
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

    # Sets Ubuntu to auto execute on login
    echo "sleep 15 && sudo ubuntu" | sudo tee ${WKDIR}/etc/bash.bashrc

    #Sets Autologin
    #autologin.conf is a script to enable auto login on tty1 on boot           
    sudo mkdir -pv ${WKDIR}/etc/systemd/system/getty@tty1.service.d         
    sudo cp -v ${BLDFL}/autologin.conf ${WKDIR}/etc/systemd/system/getty@tty1.service.d/  

   # Creates ISO and image directories
    mkdir -p image/{casper,isolinux,install}
    sudo cp ${WKDIR}/boot/vmlinuz-* image/casper/vmlinuz
    sudo cp ${WKDIR}/boot/initrd.img* image/casper/initrd.lz
    cp /usr/lib/ISOLINUX/isolinux.bin image/isolinux
    cp /usr/lib/syslinux/modules/bios/* image/isolinux
    cp /usr/lib/syslinux/memdisk image/install/memdisk
    cp /boot/memtest86+.bin image/install/memtest
    cp ${BLDFL}/isolinux.cfg image/isolinux/isolinux.cfg


    #Compressess the Source Ubuntu Chroot into the image/boot file
    sudo mksquashfs ${WKDIR} image/casper/filesystem.squashfs -e image/boot
}

function mkiso() {

    #Copies the required files for future USB Builds if required and builds the ISO Image
    sudo cp ${BLDFL}/README.diskdefines image/
    touch image/ubuntu
    mkdir image/.disk
    cd image/.disk
    touch base_installable
    echo "full_cd/single" > cd_type
    echo "Ubuntu" > info
    echo "Release Notes URL" > release_notes_url
    cd ../..


    #Makes the Source ISO File
    cd image
    sudo xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c isolinux/boot.cat -b isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4  -boot-info-table -eltorito-alt-boot -no-emul-boot \
    -isohybrid-gpt-basdat -output"../UbuntuLive.iso" .
}

main() {
    cleanup
    buildubuntu
    buildenv
    mkboot
    mkiso
    cleanup
}

main