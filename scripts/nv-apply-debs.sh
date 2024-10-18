#!/bin/bash

# Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# This host-side script applies the Debian packages to the rootfs dir
# pointed to by L4T_ROOTFS_DIR/opt/nvidia/l4t-packages.
#

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

set -e

# show the usages text
function ShowUsage {
	local ScriptName=$1

	echo "Use: sudo "${ScriptName}" [--root|-r] [--help|-h]"
cat <<EOF
	This target-side script copies over tegra debian packages
	Options are:
	--root|-r
				   Specify root directory
	--help|-h
				   show this help
EOF
}

function AddDebsList {
	local category="${1}"

	if [ -z "${category}" ]; then
		echo "Category not specified"
		exit 1
	fi

	for deb in "${L4T_ROOTFS_DEB_DIR}/${category}"/*.deb; do
		deb_name=$(basename ${deb})
		if [[ "${deb_name}" == "nvidia-l4t-ccp"* ]]; then
			pre_deb_list+=("${L4T_TARGET_DEB_DIR}/${category}/${deb_name}")
		elif [[ "${deb_name}" == "switch-joystick"* ]] || [[ "${deb_name}" == "nintendo-switch-meta"* ]] || [[ "${deb_name}" == "switch-bsp"* ]]; then
			post_deb_list+=("${L4T_TARGET_DEB_DIR}/${category}/${deb_name}")
		# elif [[ "${deb_name}" == "joycond"* ]]; then
		# 	unpack_deb_list+=("${L4T_TARGET_DEB_DIR}/${category}/${deb_name}")
		elif [[ "${deb_name}" == "xserver-"* ]]; then
			downgrade_deb_list+=("${L4T_TARGET_DEB_DIR}/${category}/${deb_name}")
		else
			deb_list+=("${L4T_TARGET_DEB_DIR}/${category}/${deb_name}")
		fi
	done
}

# if the user is not root, there is not point in going forward
THISUSER=`whoami`
if [ "${THISUSER}" != "root" ]; then
	echo "This script requires root privilege"
	exit 1
fi

# parse the command line first
# TGETOPT=`getopt -n "$SCRIPT_NAME" --longoptions help,root,image_type: \
# -o hcri: -- "$@"`

TGETOPT=`getopt -n "$SCRIPT_NAME" --longoptions help,root,image_type: -o h:r:i: -- "$@"`

eval set -- "$TGETOPT"

while [ $# -gt 0 ]; do
	case "$1" in
	-h|--help) ShowUsage "$SCRIPT_NAME"; exit 1 ;;
	-r|--root) L4T_ROOTFS_DIR="$2"; shift ;;
	-i|--image_type) IMAGE_TYPE="$2"; shift ;;
	--) shift; break ;;
	-*) echo "Terminating... wrong switch: $@" >&2 ; ShowUsage "$SCRIPT_NAME"; \
	exit 1 ;;
	esac
	shift
done

echo "$1 $2 $#"

if [ $# -gt 0 ]; then
	ShowUsage "$SCRIPT_NAME"
	exit 1
fi

# done, now do the work, save the directory
ROOT_DIR="$(cd `dirname $0` && cd .. && pwd)"

# use default rootfs dir if none is set
if [ -z "$L4T_ROOTFS_DIR" ]; then
	L4T_ROOTFS_DIR="${ROOT_DIR}/output/rootfs"
fi

status "Root file system directory is ${L4T_ROOTFS_DIR}"

# dir on target rootfs to keep Debian packages prior to installation
L4T_TARGET_DEB_DIR="/opt/nvidia/l4t-packages"
L4T_ROOTFS_DEB_DIR="${L4T_ROOTFS_DIR}${L4T_TARGET_DEB_DIR}"

# copy debian packages and installation script to rootfs
status "Copying public debian packages to rootfs"
mkdir -p "${L4T_ROOTFS_DEB_DIR}/userspace"
mkdir -p "${L4T_ROOTFS_DEB_DIR}/kernel"
mkdir -p "${L4T_ROOTFS_DEB_DIR}/bootloader"
# FIXME: create blacklist.d so that switch-bsp postinst does not fail
mkdir -p "${L4T_ROOTFS_DIR}/etc/apport/blacklist.d"
#mkdir -p "${L4T_ROOTFS_DEB_DIR}/standalone"
# pre_deb_list includes Debian packages which must be installed before
# deb_list
pre_deb_list=()
deb_list=()
# unpack_deb_list=()
post_deb_list=()
downgrade_deb_list=()

cp "${ROOT_DIR}/files/non-repo-packages"/*.deb \
"${L4T_ROOTFS_DEB_DIR}/userspace"
AddDebsList "userspace"

# if [ "${#deb_list[@]}" -eq 0 ]; then
# 	echo "No packages to install. There might be something wrong"
# 	exit 1
# fi


status "Start L4T BSP package installation"
# Try the stashed copy which should be packed in customer_release.tbz2 first
if [ -f "${L4T_DIR}/../qemu-aarch64-static" ]; then
	QEMU_BIN="${L4T_DIR}/../qemu-aarch64-static"
elif [ -f "${ROOT_DIR}/files/qemu-aarch64-static" ]; then
	QEMU_BIN="${ROOT_DIR}/files/qemu-aarch64-static"
else
	echo "QEMU binary is not available, looking for QEMU from host system"
	if [ -f "/usr/bin/qemu-aarch64-static" ]; then
		echo "Found /usr/bin/qemu-aarch64-static"
		QEMU_BIN="/usr/bin/qemu-aarch64-static"
	fi

	if [ -z "${QEMU_BIN}" ]; then
		echo "ERROR qemu not found! To install - please run: " \
			"\"sudo apt-get install qemu-user-static\""
		exit 1
	fi
fi
echo "Installing QEMU binary in rootfs"
install --owner=root --group=root "${QEMU_BIN}" "${L4T_ROOTFS_DIR}/usr/bin/"

echo "Installing host resolv.conf in rootfs"
sudo mv "${L4T_ROOTFS_DIR}/etc/resolv.conf" "${L4T_ROOTFS_DIR}/etc/resolv.conf.backup"
sudo cp -b /etc/resolv.conf "${L4T_ROOTFS_DIR}/etc/resolv.conf"

# echo "Installing Jetson OTA server key in rootfs"
# install --owner=root --group=root \
# 	"${ROOT_DIR}/files/repo/jetson-ota-public.key" \
# 	"${L4T_ROOTFS_DIR}/etc/apt"
# pushd "${L4T_ROOTFS_DIR}"
# echo "Registering Jetson OTA server key"
# LC_ALL=C chroot . mount -t proc none /proc
# LC_ALL=C APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 chroot . apt-key add "/etc/apt/jetson-ota-public.key"
# umount ${L4T_ROOTFS_DIR}/proc
# popd
# echo "Removing Jetson OTA server key from rootfs"
# rm -f "${L4T_ROOTFS_DIR}/etc/apt/jetson-ota-public.key"

# echo "Installing Switchroot OTA server key in rootfs"
# install --owner=root --group=root \
# 	"${ROOT_DIR}/files/repo/switchroot.key" \
# 	"${L4T_ROOTFS_DIR}/etc/apt"
# pushd "${L4T_ROOTFS_DIR}"
# echo "Registering Switchroot OTA server key"
# LC_ALL=C chroot . mount -t proc none /proc
# LC_ALL=C APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 chroot . apt-key add "/etc/apt/switchroot.key"
# umount ${L4T_ROOTFS_DIR}/proc
# popd
# echo "Removing Switchroot OTA server key from rootfs"
# rm -f "${L4T_ROOTFS_DIR}/etc/apt/switchroot.key"

status "Installing theofficialgman-L4T OTA server key in rootfs"
install --owner=root --group=root --mode=644 \
	"${ROOT_DIR}/files/repo/theofficialgman-L4T.key" \
	"${L4T_ROOTFS_DIR}/etc/apt/keyrings/theofficialgman-L4T.asc"
case "$IMAGE_TYPE" in
gnome-noble)
status "Installing ubuntu.sources in rootfs"
install --owner=root --group=root --mode=644 \
	"${ROOT_DIR}/files/overwrite-files/noble/gnome/sources.list" \
	"${L4T_ROOTFS_DIR}/etc/apt/sources.list"
install --owner=root --group=root --mode=644 \
	"${ROOT_DIR}/files/overwrite-files/noble/gnome/ubuntu.sources" \
	"${L4T_ROOTFS_DIR}/etc/apt/sources.list.d/ubuntu.sources"
;;
esac
pushd "${L4T_ROOTFS_DIR}"
case "$IMAGE_TYPE" in
*-jammy)
echo "deb [signed-by=/etc/apt/keyrings/theofficialgman-L4T.asc] https://theofficialgman.github.io/l4t-debs/ l4t jammy" > "${L4T_ROOTFS_DIR}/etc/apt/sources.list.d/theofficialgman-L4T.list"
# 32.7 repo by default test for jetson nano
# echo "deb [signed-by=/etc/apt/keyrings/theofficialgman-L4T.asc] https://theofficialgman.github.io/l4t-debs/ l4t jammy-32-7" > "${L4T_ROOTFS_DIR}/etc/apt/sources.list.d/theofficialgman-L4T-32-7.list"
;;
*-noble)
echo "deb [signed-by=/etc/apt/keyrings/theofficialgman-L4T.asc] https://theofficialgman.github.io/l4t-debs/ l4t noble" > "${L4T_ROOTFS_DIR}/etc/apt/sources.list.d/theofficialgman-L4T.list"
;;
*)
error "No apt repo for specified input $IMAGE_TYPE"
;;
esac
popd

pushd "${L4T_ROOTFS_DIR}"
touch "${L4T_ROOTFS_DEB_DIR}/.nv-l4t-disable-boot-fw-update-in-preinstall"

# creating mounts needed for apt
LC_ALL=C chroot . mount -t proc none /proc
mount /sys ./sys -o bind
mount /dev ./dev -o bind
mount /dev/pts ./dev/pts -o bind

status "Removing packages"
case "$IMAGE_TYPE" in
*jammy)
LC_ALL=C chroot . apt purge --autoremove -y fwupd-signed fwupdate unattended-upgrades snapd
;;
*noble)
LC_ALL=C chroot . apt purge --autoremove -y calamares fwupd-signed fwupdate unattended-upgrades snapd
;;
esac
case "$IMAGE_TYPE" in
kde*)
# kde
LC_ALL=C chroot . apt purge --autoremove -y grub-efi-*
;;
unity*)
# kde
LC_ALL=C chroot . apt purge --autoremove -y grub-efi-*
;;
gnome-jammy)
# gnome jammy
LC_ALL=C chroot . apt purge --autoremove -y linux-image-*-raspi linux-modules-*-raspi linux-headers-*-raspi linux-firmware-raspi* u-boot-rpi ubuntu-desktop-raspi linux-image-raspi linux-raspi linux-headers-raspi pi-bluetooth
;;
gnome-noble)
# gnome noble
LC_ALL=C chroot . apt purge --autoremove -y linux-image-*-raspi linux-modules-*-raspi linux-headers-*-raspi linux-firmware-raspi* u-boot-rpi ubuntu-desktop-raspi linux-image-raspi linux-raspi linux-headers-raspi pi-bluetooth cloud-init
;;
esac

status "Fully upgrade image and install additional dependencies from ubuntu repos"
LC_ALL=C chroot . apt update
LC_ALL=C chroot . apt upgrade -y
#FIXME: gir1.2-appindicator3-0.1 should be in switch-* (appropriate DE) package if needed
LC_ALL=C chroot . apt install -y gir1.2-appindicator3-0.1 bridge-utils net-tools feh onboard openbox
case "$IMAGE_TYPE" in
kde*)
# kde

# test kubuntu backports ppa
# LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot . add-apt-repository ppa:kubuntu-ppa/backports-extra -y
# LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot . add-apt-repository ppa:kubuntu-ppa/backports -y
# LC_ALL=C chroot . apt update
# LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot . apt dist-upgrade -y

LC_ALL=C chroot . apt install -y --autoremove nintendo-switch-meta switch-kde switch-multimedia --no-install-recommends gnome-software- plasma-discover-backend-fwupd-
LC_ALL=C chroot . apt install -y --no-install-recommends oem-config oem-config-kde
;;
unity*)
# unity
LC_ALL=C chroot . apt install -y --autoremove nintendo-switch-meta switch-unity switch-multimedia --no-install-recommends
LC_ALL=C chroot . apt install -y --no-install-recommends oem-config oem-config-gtk
;;
gnome*)
# gnome
LC_ALL=C chroot . apt install -y --autoremove nintendo-switch-meta switch-gnome switch-multimedia --no-install-recommends totem-
;;
esac
LC_ALL=C chroot . apt install -y chromium-browser

case "$IMAGE_TYPE" in
*-noble)
# downgrade plymouth on noble to version in theofficialgman repo
LC_ALL=C chroot . apt install --only-upgrade --allow-downgrades -y libplymouth-dev=22.02.122-3ubuntu2 libplymouth5=22.02.122-3ubuntu2 plymouth-label-ft=22.02.122-3ubuntu2 plymouth-label=22.02.122-3ubuntu2 plymouth-theme-spinner=22.02.122-3ubuntu2 plymouth-theme-ubuntu-text=22.02.122-3ubuntu2 plymouth-themes=22.02.122-3ubuntu2 plymouth-x11=22.02.122-3ubuntu2 plymouth=22.02.122-3ubuntu2
;;
esac

sleep 10
umount ${L4T_ROOTFS_DIR}/proc
umount ${L4T_ROOTFS_DIR}/sys
umount ${L4T_ROOTFS_DIR}/dev/pts
umount ${L4T_ROOTFS_DIR}/dev

# echo "Installing BSP Debian packages in ${L4T_ROOTFS_DIR}"
# if [ "${#pre_deb_list[@]}" -ne 0 ]; then
# 	LC_ALL=C chroot . dpkg -i --path-include="/usr/share/doc/*" "${pre_deb_list[@]}"
# fi

# LC_ALL=C chroot . mount -t proc none /proc
# LC_ALL=C chroot . apt update
# LC_ALL=C chroot . apt install -o Dpkg::Options::="--force-overwrite" "${deb_list[@]}" -y
# umount ${L4T_ROOTFS_DIR}/proc
# if [ "${#post_deb_list[@]}" -ne 0 ]; then
# 	LC_ALL=C chroot . dpkg -i --path-include="/usr/share/doc/*" "${post_deb_list[@]}"
# fi

if [ "${#downgrade_deb_list[@]}" -ne 0 ]; then
	LC_ALL=C chroot . mount -t proc none /proc
	LC_ALL=C chroot . apt install --allow-downgrades --autoremove -y "${downgrade_deb_list[@]}"
	umount ${L4T_ROOTFS_DIR}/proc
fi

# mark packages as auto so they get removed after initial setup completes as they are no longer needed
LC_ALL=C chroot . mount -t proc none /proc
LC_ALL=C chroot . apt-mark auto feh onboard openbox
umount ${L4T_ROOTFS_DIR}/proc

# # install packages without configuration
# LC_ALL=C chroot . dpkg --unpack --path-include="/usr/share/doc/*" "${unpack_deb_list[@]}"

rm -f "${L4T_ROOTFS_DEB_DIR}/.nv-l4t-disable-boot-fw-update-in-preinstall"

# remove machine-id to be generated on first boot
LC_ALL=C chroot . rm -f /var/lib/dbus/machine-id
LC_ALL=C chroot . truncate --size 0 /etc/machine-id

popd

echo "Removing QEMU binary from rootfs"
rm -f "${L4T_ROOTFS_DIR}/usr/bin/qemu-aarch64-static"

echo "Restoring resolv.conf in rootfs"
sudo rm -f "${L4T_ROOTFS_DIR}/etc/resolv.conf"
sudo mv "${L4T_ROOTFS_DIR}/etc/resolv.conf.backup" "${L4T_ROOTFS_DIR}/etc/resolv.conf"

echo "Removing stashed Debian packages from rootfs"
rm -rf "${L4T_ROOTFS_DEB_DIR}"

status_green "L4T BSP package installation completed!"
exit 0
