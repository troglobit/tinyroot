#!/bin/sh -e

KERNEL_VERSION=4.15.4
KERNEL=linux-${KERNEL_VERSION}
KERNEL_BUILD=rootfs/lib/modules/${KERNEL_VERSION}/build
BUSYBOX=busybox-1.25.0

# Set up toolcahin
export PATH=/usr/local/arm-unknown-linux-gnueabi-7.3.0-1/bin:$PATH
export ARCH=arm
export CROSS_COMPILE=arm-unknown-linux-gnueabi-

msg() {
    /bin/echo -e "\x1b[1;34m--- "$1"\x1b[0m"
}

fetch() {
    if [ ! -f $1 ]; then
	wget -O $1.tmp $2
	mv $1.tmp $1
    fi
    tar xf $1
}

msg "Creating rootfs ..."
for dir in boot dev etc/init.d proc sys mnt lib bin sbin var run; do
    mkdir -p rootfs/$dir
done
echo '#!/bin/sh' > rootfs/etc/init.d/rcS
chmod 0755 rootfs/etc/init.d/rcS

msg "Fetching, unpacking, and configuring kernel ..."
fetch ${KERNEL}.tar.xz https://cdn.kernel.org/pub/linux/kernel/v4.x/${KERNEL}.tar.xz
mkdir images
cd ${KERNEL}/
cp ../linux.config .config
make oldconfig
make -j5
INSTALL_PATH=../images make install && cp arch/arm/boot/zImage ../images/
INSTALL_DTBS_PATH=../images make dtbs dtbs_install
INSTALL_MOD_PATH=../rootfs INSTALL_MOD_STRIP=--strip-all make modules_install
cd ..

msg "Fetching, unpackng, and configuring BusyBox ..."
fetch ${BUSYBOX}.tar.bz2 http://busybox.net/downloads/${BUSYBOX}.tar.bz2
cd ${BUSYBOX}/
cp ../busybox.config .config
make oldconfig
make -j5
make install
cd ..

msg "Generating tinyroot ..."
${KERNEL_BUILD}/scripts/gen_initramfs_list.sh -u squash -g squash rootfs > init.ramfs
cat tiny.ramfs init.ramfs | ${KERNEL_BUILD}/usr/gen_init_cpio - >images/tinyroot.cpio
gzip -f9 images/tinyroot.cpio

msg "Done, now run ./qemu.sh"
