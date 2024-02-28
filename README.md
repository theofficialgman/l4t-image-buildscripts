# l4t-image-buildscripts
 
This repo contains the buildscripts used to create Switchroot L4T Ubuntu Noble and Jammy images.

Kubuntu and Ubuntu-Unity clean ubuntu rootfs are found in https://github.com/theofficialgman/l4t-image-buildscripts/releases/tag/rootfs-assets<br />
Download the corresponding rootfs to the `files/rootfs/noble` folder to create Kubuntu Noble and Ubuntu-Unity Noble images.

Ubuntu (GNOME) images are created starting with the official raspberry pi preinstalled image files.<br />
The ubuntu jammy version used is https://old-releases.ubuntu.com/releases/22.04/ubuntu-22.04.3-preinstalled-desktop-arm64+raspi.img.xz<br />
The ubuntu noble version used is https://cdimage.ubuntu.com/daily-preinstalled/pending/noble-preinstalled-desktop-arm64+raspi.img.xz<br />
Download the corresponding image to the folder `files/rootfs/jammy` or `files/rootfs/noble` and decompress the img.xz so you have an img

the script to build the `7z` image archive can be run as such:
`./scripts/apply.sh kde-noble` where possible input is  `gnome-jammy` `gnome-noble` `kde-noble` and `unity-noble`<br />
the script operates in the `output` folder of the root folder of this repo and that is where you will find the `7z` image archive when completed