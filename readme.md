# Ubuntu Live Scripts

## CONTENTS

1. Description
2. How to build
3. Customising
4. Building to USB


## DESCRIPTION

This is a Set of Shell Scripts and files based upon the ubuntu documentation at https://help.ubuntu.com/community/LiveCDCustomizationFromScratch this is designed to work with xenial, and is only for creating a standalone live USB or CD that has a light version of ubuntu on there.


## HOW TO BUILD

Ensure the shell script has execute permissions

```
    chmod +x ./build.sh
```


Run the following command


```
    sudo ./build.sh
```

This will create a base iso.

## CUSTOMISING

You can customise the packages as required by editing the chroot function and inserting. See the build.sh file for the reccomended installation point

```
    apt install --yes <PackageName>
```

For packages that call a conformation screen, such as grub you will need to use

```
    DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" <PackageName>
```

If you are baking in Graphics Card Drivers, such as NVIDIA, you will need to do the following. This will ensure a desktop environment is not installed so you can choose your own flavour.

```
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-reccomends -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" nvidia-340

```

Other deb packages can be installed by inserting the following command. 
```
    dpkg -i <PackageName>

```

## BUILDING TO USB

Once the ISO has been built the project can be exported to usb by opening disks in ubuntu, selecting the USB Drive, then restore disk in the options menu. This will place the ISO onto the USB.

Please note there is no EFI / Grub configured in this build, it is purely based on ISOLINUX
