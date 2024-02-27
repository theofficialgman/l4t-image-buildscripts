#!/bin/bash

# Copyright (c) 2019-2021, NVIDIA CORPORATION.  All rights reserved.
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

# Remove unused services, target, script, and config files
DEFAULT_TARGET="$(/bin/systemctl get-default)"
if [ "${DEFAULT_TARGET}" != "nv-oem-config.target" ]; then
	CHIP="$(cat /proc/device-tree/compatible)"
	if [[ "${CHIP}" =~ "tegra194" ]]; then
		/bin/systemctl start serial-getty@ttyTCU0.service
	else
		/bin/systemctl start serial-getty@ttyS0.service
	fi

	/bin/systemctl restart nv-l4t-usb-device-mode.service
	/bin/systemctl start serial-getty@ttyGS0.service

	rm -f /lib/systemd/system/nv-oem-config*.*
	rm -f /usr/sbin/nv-oem-config-firstboot
	rm -f /etc/systemd/nv-oem-config*.sh
	rm -f /etc/nv-oem-config.conf.*
else
	/bin/echo "System configuration setup wasn't completed. \
Please reboot device and try again. " > "/dev/kmsg"
	/bin/echo "System configuration setup wasn't completed. \
Please reboot device and try again. " > "/dev/ttyGS0"
fi
