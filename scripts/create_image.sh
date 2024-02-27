#!/bin/bash

# move to current script directory regardless of where the script was run from
cd `dirname $0` || exit 1
cd ../output

echo ---- Creating empty image
sync
bytes="$(du -sb rootfs | awk '{ print $1 }')"
dd if=/dev/zero of=l4t.ext4.img bs=4194304 count=$(($bytes / 4194304 + 200))
# dd if=/dev/zero of=l4t.ext4.img bs=4194304 count=1950
echo ---- Formatting to ext4
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
echo ---- Copying files
sync
cp -a rootfs/* mounted_ext4/ && sync
sync
umount mounted_ext4
echo ---- Cleaning up free space
zerofree l4t.ext4.img

echo ---- Spliting image
split -b4290772992 --numeric-suffixes=0 "l4t.ext4.img" "l4t."
#rm -f l4t.ext4.img
sync
