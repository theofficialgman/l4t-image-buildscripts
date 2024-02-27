#!/bin/bash

# move to current script directory regardless of where the script was run from
cd `dirname $0` || exit 1
SCRIPTS_DIR="$(pwd)"
cd .. || exit 1
ROOT_DIR="$(pwd)"
# move to output folder
mkdir -p output
cd output || exit 1
OUTPUT_DIR="$(pwd)"
echo ---- Removing old rootfs
sync
sudo rm -rf rootfs
sync
echo ---- Extracting rootfs
if [[ "$1" == "kde-jammy" ]]; then
  export IMAGE_TYPE=kde-jammy
  echo "KDE Ubuntu Jammy image creation selected."
elif [[ "$1" == "kde-noble" ]]; then
  export IMAGE_TYPE=kde-noble
  echo "KDE Ubuntu Noble image creation selected."
elif [[ "$1" == "gnome-jammy" ]]; then
  export IMAGE_TYPE=gnome-jammy
  echo "GNOME Ubuntu Jammy image creation selected."
elif [[ "$1" == "gnome-noble" ]]; then
  export IMAGE_TYPE=gnome-noble
  echo "GNOME Ubuntu Noble image creation selected."
elif [[ "$1" == "unity-noble" ]]; then
  export IMAGE_TYPE=unity-noble
  echo "Ubuntu Unity Noble image creation selected."
elif [[ "$1" == "experiment" ]]; then
  export IMAGE_TYPE=experiment
  echo "experiment image creation selected."
else
  export IMAGE_TYPE=gnome-jammy
  echo "No option specified, defaulting to GNOME image creation."
fi

case "$IMAGE_TYPE" in
kde-jammy)
# kde
sudo mkdir rootfs
sudo tar -xf ../files/rootfs/jammy/kubuntu-jammy-base-final.tar.gz -C rootfs
;;
kde-noble)
# kde
sudo mkdir rootfs
sudo tar -xf ../files/rootfs/noble/kubuntu-noble-base-prerelease.tar.gz -C rootfs
;;
unity-noble)
# unity
sudo mkdir rootfs
sudo tar -xf ../files/rootfs/noble/ubuntu-unity-noble-prerelease.tar.gz -C rootfs
;;
gnome-jammy)
# gnome
rm -rf /tmp/rootfs-mount
mkdir -p /tmp/rootfs-mount
loopdev=$(sudo losetup -f --show -P ../files/rootfs/jammy/ubuntu-22.04.3-preinstalled-desktop-arm64+raspi.img)
sudo mount ${loopdev}p2 /tmp/rootfs-mount
sudo cp -rp /tmp/rootfs-mount rootfs
sudo umount /tmp/rootfs-mount
sudo losetup -d ${loopdev}
;;
gnome-noble)
# gnome
rm -rf /tmp/rootfs-mount
mkdir -p /tmp/rootfs-mount
loopdev=$(sudo losetup -f --show -P ../files/rootfs/noble-preinstalled-desktop-arm64+raspi.img)
sudo mount ${loopdev}p2 /tmp/rootfs-mount
sudo cp -rp /tmp/rootfs-mount rootfs
sudo umount /tmp/rootfs-mount
sudo losetup -d ${loopdev}
;;
*)
echo "No image for specified input $IMAGE_TYPE"
exit 1
;;
esac

cd rootfs
sudo mkdir -p opt
sudo mkdir -p opt/switchroot
sudo touch opt/switchroot/image_prep
cd ..
echo ---- Applying BSP
sync
sudo "$SCRIPTS_DIR"/apply_binaries.sh -i "$IMAGE_TYPE" || exit $?
cd ..

echo 
echo 
echo ---- Applying Switchroot customizations

#first boot script customizations
sudo mkdir -p "$OUTPUT_DIR"/rootfs/usr/lib/ubiquity/dm-scripts/oem
sudo cp "$ROOT_DIR"/files/overwrite-files/switch-randr "$OUTPUT_DIR"/rootfs/usr/lib/ubiquity/dm-scripts/oem/switch-randr
sudo cp "$ROOT_DIR"/files/overwrite-files/ubiquity-dm "$OUTPUT_DIR"/rootfs/usr/bin/ubiquity-dm
sudo rm "$OUTPUT_DIR"/rootfs/usr/share/xsessions/openbox.desktop
sudo cp "$ROOT_DIR"/files/overwrite-files/nv-oem-config-post.sh "$OUTPUT_DIR"/rootfs/etc/systemd/nv-oem-config-post.sh

#FIXME: these should be handled in packages
sudo cp "$ROOT_DIR"/files/overwrite-files/custom.conf "$OUTPUT_DIR"/rootfs/etc/gdm3/custom.conf
sudo ln -s /lib/systemd/system/iio-sensor-proxy.service "$OUTPUT_DIR"/rootfs/etc/systemd/system/multi-user.target.wants/iio-sensor-proxy.service

#FIXME: go through this list
echo ---- Cleaning up unneeded files in the image
sudo rm "$OUTPUT_DIR"/rootfs/etc/skel/Desktop/nv_devzone.desktop
sudo rm "$OUTPUT_DIR"/rootfs/etc/skel/Desktop/nv_forums.desktop
sudo rm "$OUTPUT_DIR"/rootfs/etc/skel/Desktop/nv_jetson_zoo.desktop
sudo rm -rf "$OUTPUT_DIR"/rootfs/lib/firmware/amdgpu
sudo rm -rf "$OUTPUT_DIR"/rootfs/lib/firmware/radeon
sudo rm -rf "$OUTPUT_DIR"/rootfs/lib/firmware/radeon
sudo rm "$OUTPUT_DIR"/rootfs/var/cache/apt/pkgcache.bin
sudo rm "$OUTPUT_DIR"/rootfs/var/cache/apt/srcpkgcache.bin
sudo rm "$OUTPUT_DIR"/rootfs/var/cache/debconf/templates.dat-old
sudo rm "$OUTPUT_DIR"/rootfs/var/cache/debconf/config.dat-old
sudo rm -rf "$OUTPUT_DIR"/rootfs/usr/src/nvidia/graphics_demos/prebuilts
sudo rm "$OUTPUT_DIR"/rootfs/usr/share/backgrounds/Manhattan_Sunset_by_Giacomo_Ferroni.jpg
sudo rm -rf "$OUTPUT_DIR"/rootfs/usr/share/example-content/Ubuntu_Free_Culture_Showcase
sudo cp "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so nouveau_dri.so
sudo cp "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/nouveau_drv_video.so nouveau_drv_video.so
sudo cp "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/nouveau_vieux_dri.so nouveau_vieux_dri.so
sudo rm "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/*
sudo mv nouveau_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so
sudo mv nouveau_drv_video.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/nouveau_drv_video.so
sudo mv nouveau_vieux_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/nouveau_vieux_dri.so
sudo ln -s /usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/kgsl_dri.so
sudo ln -s /usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/kms_swrast_dri.so
sudo ln -s /usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/meson_dri.so
sudo ln -s /usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/swrast_dri.so
sudo ln -s /usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/tegra_dri.so
sudo ln -s /usr/lib/aarch64-linux-gnu/dri/nouveau_dri.so "$OUTPUT_DIR"/rootfs/usr/lib/aarch64-linux-gnu/dri/virtio_gpu_dri.so

sudo rm "$OUTPUT_DIR"/rootfs/usr/lib/ubiquity/plugins/nvresizefs.py
sudo rm -rf "$OUTPUT_DIR"/rootfs/usr/lib/nvidia/resizefs

sudo "$SCRIPTS_DIR"/create_image.sh "$IMAGE_TYPE"
