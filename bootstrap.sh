#!/bin/sh

KERNEL_VERSION=4.15.4
KERNEL=linux-${KERNEL_VERSION}
KERNEL_BUILD=rootfs/lib/modules/${KERNEL_VERSION}/build
BUSYBOX=busybox-1.25.0

# Set up toolcahin
export PATH=/usr/local/arm-unknown-linux-gnueabi-7.3.0-1/bin:$PATH
export ARCH=arm
export CROSS_COMPILE=arm-unknown-linux-gnueabi-
export MAKE="make --silent --no-print-directory"

msg() {
    /bin/echo -e "\x1b[1;34m--- "$1"\x1b[0m"
}

err() {
    /bin/echo -e "\x1b[1;33m--- "$1"\x1b[0m"
    exit 1
}

query() {
    /bin/echo -ne "\x1b[1;34m--- "$1"\x1b[0m"
}

fetch() {
    if [ ! -f $1 ]; then
	wget -O $1.tmp $2
	mv $1.tmp $1
    fi
    tar xf $1
}

${CROSS_COMPILE}gcc --version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    err "Cannot find ${CROSS_COMPILE}gcc in PATH, try one from http://ftp.troglobit.com/pub/Toolchains/"
fi

# Enable error on first strike
set -e

msg "Populating rootfs ..."
mkdir -p rootfs/etc/init.d
echo '#!/bin/sh' > rootfs/etc/init.d/rcS
chmod 0755 rootfs/etc/init.d/rcS

msg "Fetching, unpacking, and configuring kernel ..."
fetch ${KERNEL}.tar.xz https://cdn.kernel.org/pub/linux/kernel/v4.x/${KERNEL}.tar.xz
mkdir -p images
cd ${KERNEL}/
cp ../linux.config .config
${MAKE} oldconfig
${MAKE} -j5
INSTALL_PATH=../images      ${MAKE} install && cp arch/arm/boot/zImage ../images/
INSTALL_DTBS_PATH=../images ${MAKE} dtbs dtbs_install
INSTALL_MOD_PATH=../rootfs INSTALL_MOD_STRIP=--strip-unneeded ${MAKE} modules_install
cd ..

msg "Fetching, unpacking, and configuring BusyBox ..."
fetch ${BUSYBOX}.tar.bz2 http://busybox.net/downloads/${BUSYBOX}.tar.bz2
cd ${BUSYBOX}/
cp ../busybox.config .config
${MAKE} oldconfig
${MAKE} -j5
${MAKE} install
cd ..

msg "Generating tinyroot ..."
${KERNEL_BUILD}/scripts/gen_initramfs_list.sh -u squash -g squash rootfs > init.ramfs
cat tiny.ramfs init.ramfs | ${KERNEL_BUILD}/usr/gen_init_cpio - >images/tinyroot.cpio
gzip -f9 images/tinyroot.cpio

query "Done, do you want to test the image with Qemu (y/N)? "
read yorn
if [ "$yorn" != "y" -a "$yorn" != "Y" ]; then
    msg "Aborting Qemu."
    exit 0
else
    msg "Starting Qemu ..."
fi

export QEMU_AUDIO_DRV=none
qemu-system-arm -m 256M -M versatileab -rtc base=utc,clock=rt -nographic \
		-net bridge,br=virbr0 -net nic,model=smc91c111           \
		-kernel images/zImage  -dtb images/versatile-ab.dtb      \
		-initrd images/tinyroot.cpio.gz                          \
		-append 'root=/dev/rom0 console=ttyAMA0 mem=256M quiet splash'
