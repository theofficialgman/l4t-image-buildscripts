#!/bin/bash

# Copyright (c) 2011-2019, NVIDIA CORPORATION. All rights reserved.
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
# This script applies the binaries to the rootfs dir pointed to by
# LDK_ROOTFS_DIR variable.
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

    echo "Use: $1 [--root|-r PATH] [--help|-h]"
cat <<EOF
    This script installs tegra binaries
    Options are:
    --root|-r PATH
                   install toolchain to PATH
    --help|-h
                   show this help
EOF
}

function ShowDebug {
    echo "SCRIPT_NAME     : $SCRIPT_NAME"
    echo "DEB_SCRIPT_NAME : $DEB_SCRIPT_NAME"
    echo "LDK_ROOTFS_DIR  : $LDK_ROOTFS_DIR"
    echo "BOARD_NAME      : $TARGET_BOARD"
}

function ReplaceText {
	sed -i "s/$2/$3/" $1
	if [ $? -ne 0 ]; then
		echo "Error while editing a file. Exiting !!"
		exit 1
	fi
}
# if the user is not root, there is not point in going forward
THISUSER=`whoami`
if [ "x$THISUSER" != "xroot" ]; then
    echo "This script requires root privilege"
    exit 1
fi

# script name
SCRIPT_NAME=`basename $0`

# apply .deb script name
DEB_SCRIPT_NAME="nv-apply-debs.sh"

# empty root and no debug
DEBUG=

# parse the command line first
TGETOPT=`getopt -n "$SCRIPT_NAME" --longoptions help,bsp:,debug,target-overlay,root,image_type: -o b:dhr:b:t:i: -- "$@"`

if [ $? != 0 ]; then
    echo "Terminating... wrong switch"
    ShowUsage "$SCRIPT_NAME"
    exit 1
fi

eval set -- "$TGETOPT"

while [ $# -gt 0 ]; do
    case "$1" in
	-r|--root) LDK_ROOTFS_DIR="$2"; shift ;;
	-i|--image_type) IMAGE_TYPE="$2"; shift ;;
	-h|--help) ShowUsage "$SCRIPT_NAME"; exit 1 ;;
	-d|--debug) DEBUG="true" ;;
	--) shift; break ;;
	-*) echo "Terminating... wrong switch: $@" >&2 ; ShowUsage "$SCRIPT_NAME"; exit 1 ;;
    esac
    shift
done

if [ $# -gt 0 ]; then
    ShowUsage "$SCRIPT_NAME"
    exit 1
fi

# done, now do the work, save the directory
LDK_DIR=$(cd `dirname $0` && pwd)
ROOT_DIR="$(cd `dirname $0` && cd .. && pwd)"

# use default rootfs dir if none is set
if [ -z "$LDK_ROOTFS_DIR" ]; then
    LDK_ROOTFS_DIR="$(cd ../output/rootfs && pwd)"
fi

echo "Using rootfs directory of: ${LDK_ROOTFS_DIR}"

install -o 0 -g 0 -m 0755 -d "${LDK_ROOTFS_DIR}"

# get the absolute path, for LDK_ROOTFS_DIR.
# otherwise, tar behaviour is unknown in last command sets
TOP=$PWD
cd "$LDK_ROOTFS_DIR"
LDK_ROOTFS_DIR="$PWD"
cd "$TOP"

if [ ! `find "$LDK_ROOTFS_DIR/etc/passwd" -group root -user root` ]; then
	echo "||||||||||||||||||||||| ERROR |||||||||||||||||||||||"
	echo "-----------------------------------------------------"
	echo "1. The root filesystem, provided with this package,"
	echo "   has to be extracted to this directory:"
	echo "   ${LDK_ROOTFS_DIR}"
	echo "-----------------------------------------------------"
	echo "2. The root filesystem, provided with this package,"
	echo "   has to be extracted with 'sudo' to this directory:"
	echo "   ${LDK_ROOTFS_DIR}"
	echo "-----------------------------------------------------"
	echo "Consult the Development Guide for instructions on"
	echo "extracting and flashing your device."
	echo "|||||||||||||||||||||||||||||||||||||||||||||||||||||"
	exit 1
fi


if [ "${DEBUG}" == "true" ]; then
	START_TIME=$(date +%s)
fi


if [ ! -f "${ROOT_DIR}/scripts/${DEB_SCRIPT_NAME}" ]; then
	echo "Debian script ${ROOT_DIR}/scripts/${DEB_SCRIPT_NAME} not found"
	exit 1
fi
status "Running: ${ROOT_DIR}/scripts/${DEB_SCRIPT_NAME} -r ${LDK_ROOTFS_DIR} -i ${IMAGE_TYPE}"
"${ROOT_DIR}/scripts/${DEB_SCRIPT_NAME}" -r ${LDK_ROOTFS_DIR} -i ${IMAGE_TYPE}

ARM_ABI_DIR=

if [ -d "${LDK_ROOTFS_DIR}/usr/lib/arm-linux-gnueabihf/tegra" ]; then
	ARM_ABI_DIR_ABS="usr/lib/arm-linux-gnueabihf"
elif [ -d "${LDK_ROOTFS_DIR}/usr/lib/arm-linux-gnueabi/tegra" ]; then
	ARM_ABI_DIR_ABS="usr/lib/arm-linux-gnueabi"
elif [ -d "${LDK_ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/tegra" ]; then
	ARM_ABI_DIR_ABS="usr/lib/aarch64-linux-gnu"
else
	echo "Error: None of Hardfp/Softfp Tegra libs found"
	exit 4
fi

ARM_ABI_DIR="${LDK_ROOTFS_DIR}/${ARM_ABI_DIR_ABS}"
ARM_ABI_TEGRA_DIR="${ARM_ABI_DIR}/tegra"

install -o 0 -g 0 -m 0755 -d "${LDK_ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"
pushd "${LDK_ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants" > /dev/null 2>&1
if [ -h "isc-dhcp-server.service" ]; then
	rm -f "isc-dhcp-server.service"
fi
if [ -h "isc-dhcp-server6.service" ]; then
	rm -f "isc-dhcp-server6.service"
fi
popd > /dev/null

# Enable Unity by default for better user experience [2332219]
echo "Rename ubuntu.desktop --> ux-ubuntu.desktop"
if [ -d "${LDK_ROOTFS_DIR}/usr/share/xsessions" ]; then
	pushd "${LDK_ROOTFS_DIR}/usr/share/xsessions" > /dev/null 2>&1
	if [ -f "ubuntu.desktop" ]; then
		mv "ubuntu.desktop" "ux-ubuntu.desktop"
	fi
	popd > /dev/null
fi

if [ -e "${LDK_ROOTFS_DIR}/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf" ]; then
	grep -q -F 'allow-guest=false' \
		"${LDK_ROOTFS_DIR}/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf" \
		|| echo 'allow-guest=false' \
		>> "${LDK_ROOTFS_DIR}/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf"
fi

# test if installation comes with systemd-gpt-auto-generator. If so, disable it
# this is a WAR for https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1783994
# systemd spams log with "Failed to dissect: Input/output error" on systems with mmc
if [ -e "${LDK_ROOTFS_DIR}/lib/systemd/system-generators/systemd-gpt-auto-generator" ]; then
	if [ ! -d "${LDK_ROOTFS_DIR}/etc/systemd/system-generators" ]; then
		mkdir "${LDK_ROOTFS_DIR}/etc/systemd/system-generators"
	fi
	# this is the way to disable systemd unit auto generators by
	# symlinking the generator to null in corresponding path in /etc
	ln -sf /dev/null "${LDK_ROOTFS_DIR}/etc/systemd/system-generators/systemd-gpt-auto-generator"
fi

echo "Copying USB device mode filesystem image to ${LDK_ROOTFS_DIR}"
install -o 0 -g 0 -m 0755 -d "${LDK_ROOTFS_DIR}/opt/nvidia/l4t-usb-device-mode"
cp "${ROOT_DIR}/files/overwrite-files/l4t-usb-device-mode-filesystem.img" "${LDK_ROOTFS_DIR}/opt/nvidia/l4t-usb-device-mode/filesystem.img"

# Disabling NetworkManager-wait-online.service for Bug 200290321
echo "Disabling NetworkManager-wait-online.service"
if [ -h "${LDK_ROOTFS_DIR}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service" ]; then
	rm "${LDK_ROOTFS_DIR}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
fi

echo "Disable the ondemand service by changing the runlevels to 'K'"
for file in "${LDK_ROOTFS_DIR}"/etc/rc[0-9].d/; do
	if [ -f "${file}"/S*ondemand ]; then
		mv "${file}"/S*ondemand "${file}/K01ondemand"
	fi
done

# Remove the spawning of ondemand service
if [ -h "${LDK_ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/ondemand.service" ]; then
	rm -f "${LDK_ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/ondemand.service"
fi

# If default target does not exist and if rootfs contains gdm or sddm or lightdm, set default to nv-oem-config target
if ( [ ! -e "${LDK_ROOTFS_DIR}/etc/systemd/system/default.target" ] && [ -d "${LDK_ROOTFS_DIR}/etc/gdm3/" ] ) || ( [ ! -e "${LDK_ROOTFS_DIR}/etc/systemd/system/default.target" ] && [ -d "${LDK_ROOTFS_DIR}/etc/sddm/" ] ) || ( [ ! -e "${LDK_ROOTFS_DIR}/etc/systemd/system/default.target" ] && [ -d "${LDK_ROOTFS_DIR}/etc/lightdm/" ] ); then
	mkdir -p "${LDK_ROOTFS_DIR}/etc/systemd/system/nv-oem-config.target.wants"
	pushd "${LDK_ROOTFS_DIR}/etc/systemd/system/nv-oem-config.target.wants" > /dev/null 2>&1
	ln -sf /lib/systemd/system/nv-oem-config.service nv-oem-config.service
	ln -sf "/etc/systemd/system/nvfb-early.service" "nvfb-early.service"
	popd > /dev/null 2>&1
	pushd "${LDK_ROOTFS_DIR}/etc/systemd/system" > /dev/null 2>&1
	ln -sf /lib/systemd/system/nv-oem-config.target nv-oem-config.target
	ln -sf nv-oem-config.target default.target
	popd > /dev/null 2>&1

	extra_groups="EXTRA_GROUPS=\"audio gdm gpio i2c video weston-launch\""
	sed -i "/\<EXTRA_GROUPS\>=/ s/^.*/${extra_groups}/" \
		"${LDK_ROOTFS_DIR}/etc/adduser.conf"
	sed -i "/\<ADD_EXTRA_GROUPS\>=/ s/^.*/ADD_EXTRA_GROUPS=1/" \
		"${LDK_ROOTFS_DIR}/etc/adduser.conf"
fi

if [ -e "${LDK_ROOTFS_DIR}/etc/gdm3/custom.conf" ]; then
	sed -i "/WaylandEnable=false/ s/^#//" "${LDK_ROOTFS_DIR}/etc/gdm3/custom.conf"
fi


if [ "${DEBUG}" == "true" ]; then
	END_TIME=$(date +%s)
	TOTAL_TIME=$((${END_TIME}-${START_TIME}))
	echo "Time for applying binaries - $(date -d@${TOTAL_TIME} -u +%H:%M:%S)"
fi
status_green "Nvidia Customizations Applied!"
