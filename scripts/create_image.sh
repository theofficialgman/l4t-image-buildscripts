#!/bin/bash

error() { #red text and exit 1
  echo -e "\e[91m$1\e[0m" 1>&2
  exit 1
}

warning() { #yellow text
  echo -e "\e[93m\e[5m◢◣\e[25m WARNING: $1\e[0m" 1>&2
}

status() { #cyan text to indicate what is happening
  
  #detect if a flag was passed, and if so, pass it on to the echo command
  if [[ "$1" == '-'* ]] && [ ! -z "$2" ];then
    echo -e $1 "\e[96m$2\e[0m" 1>&2
  else
    echo -e "\e[96m$1\e[0m" 1>&2
  fi
}

status_green() { #announce the success of a major action
  echo -e "\e[92m$1\e[0m" 1>&2
}

# move to current script directory regardless of where the script was run from
cd `dirname $0` || exit 1
cd ../output || error "Failed to move to output directory"

status "Creating empty image"
sync
bytes="$(du -sb rootfs | awk '{ print $1 }')"
dd if=/dev/zero of=l4t.ext4.img bs=4194304 count=$(($bytes / 4194304 + 200))
# dd if=/dev/zero of=l4t.ext4.img bs=4194304 count=1950
status "Formatting to ext4"
sync
mkfs.ext4 -b 4096 l4t.ext4.img
case "$1" in
*-jammy)
e2label l4t.ext4.img SWR-JAM
;;
*-noble)
e2label l4t.ext4.img SWR-NOB
;;
esac
mkdir -p mounted_ext4
chown 0.0 mounted_ext4
chmod 0777 mounted_ext4
sync
mount l4t.ext4.img mounted_ext4/
status "Copying files"
sync
cp -a rootfs/* mounted_ext4/ || error "Failed to copy rootfs to mount"
sync
umount mounted_ext4
status "Cleaning up free space"
zerofree l4t.ext4.img

status "Spliting image"
split -b4290772992 --numeric-suffixes=0 "l4t.ext4.img" "l4t."
#rm -f l4t.ext4.img
sync

distro_name=$(echo "$1" | awk -F- '{print $NF}')
status "Creating L4T-$distro_name-image.7z"
rm -rf L4T-image
sudo -u "$SUDO_USER" mkdir L4T-image
cd L4T-image
sudo -u "$SUDO_USER" mkdir -p bootloader/ini switchroot/install switchroot/ubuntu-$distro_name
sudo -u "$SUDO_USER" cp ../rootfs/opt/switchroot/bootstack/* switchroot/ubuntu-$distro_name/ || error "Failed to copy bootfiles"
sudo -u "$SUDO_USER" cp ../rootfs/opt/switchroot/L4T-$distro_name.ini bootloader/ini/ || error "Failed to copy boot .ini"
sudo -u "$SUDO_USER" mv ../l4t.0* switchroot/install/ || error "Failed to copy image files"
chown -R "$SUDO_USER":"$SUDO_USER" ./*
sync
sudo -u "$SUDO_USER" 7z a ../"L4T-$distro_name-image.7z" ./* || error "Failed to create L4T-$distro_name-image.7z"


status_green "Image creation finished!"
