# l4t-image-buildscripts
 
This repo contains the buildscripts used to create Switchroot L4T Ubuntu Noble and Jammy images.

There are two steps to creating the images. First you need a clean ubuntu rootfs. Ubuntu (GNOME) ARM64 images for the Raspberry Pi from Ubuntu are available and are used instead of creating a ubuntu rootfs from scratch. Kubuntu and Ubuntu-Unity ARM64 rootfs do not exist and must be created from scratch. Next you create a hekate installable `7z` image with the custom switchroot packages added to the rootfs. The following are instructions for running two scripts that automate these processes.

To create a Kubuntu or Ubuntu-Unity rootfs from scratch run the following script:
`sudo ./scripts/nv_build_samplefs.sh --abi aarch64 --distro ubuntu --flavor kubuntu-desktop --version noble`<br />
the possible input for flavor is `kubuntu-desktop` and `ubuntu-unity-desktop` (noble only)<br />
the possible input for version is `noble` and `jammy` <br />
the script operates in the `output` folder of the root folder of this repo and that is where you will find the `tar.gz` rootfs when completed. Move that file into the `files/rootfs/noble` or `files/rootfs/jammy` for use in creating the `7z` image in the next step.

Ubuntu (GNOME) images are created starting with the official raspberry pi preinstalled image files.<br />
The ubuntu jammy version used is https://old-releases.ubuntu.com/releases/22.04/ubuntu-22.04.3-preinstalled-desktop-arm64+raspi.img.xz<br />
The ubuntu noble version used is https://cdimage.ubuntu.com/releases/noble/release/ubuntu-24.04-preinstalled-desktop-arm64+raspi.img.xz<br />
Download the corresponding image to the folder `files/rootfs/jammy` or `files/rootfs/noble` and decompress the img.xz so you have an img

the script to build the `7z` image archive can be run as such:
`./scripts/apply.sh kde-noble` where possible input is  `gnome-jammy` `gnome-noble` `kde-noble` and `unity-noble`<br />
the script operates in the `output` folder of the root folder of this repo and that is where you will find the `7z` image archive when completed
