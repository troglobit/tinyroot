KERNEL_VERSION := 4.15.4
KERNEL         := linux-$(KERNEL_VERSION)
KERNEL_BUILD   := rootfs/lib/modules/$(KERNEL_VERSION)/build

BUSYBOX        := busybox-1.25.0

LIBITE         := libite-2.0.1
LIBUEV         := libuev-2.1.2
FINIT          := finit-3.1

# Set up toolcahin
PATH           := /usr/local/arm-unknown-linux-gnueabi-7.3.0-1/bin:$(PATH)
ARCH           := arm
CROSS_COMPILE  := arm-unknown-linux-gnueabi-
CROSS_TARGET   := $(CROSS_COMPILE:-=)
CWD            := $(shell pwd)
CPPFLAGS       := -I$(CWD)/rootfs/include -I$(CWD)/rootfs/usr/include
LDFLAGS        := -L$(CWD)/rootfs/lib -L$(CWD)/rootfs/usr/lib

export PATH
export ARCH CROSS_COMPILE
export CPPFLAGS LDFLAGS

# pkg-config
PKG_CONFIG_LIBDIR := $(CWD)/rootfs/lib/pkgconfig
export PKG_CONFIG_LIBDIR

# images/tinyroot.cpio.gz
all tinyroot: images/tinyroot.img

# 
romfs/.stamp: rootfs/etc/version images/zImage rootfs/bin/busybox rootfs/sbin/finit
	@$(CROSS_COMPILE)populate -f -s rootfs -d romfs
	-@rm -rf romfs/include romfs/lib/pkgconfig romfs/share/doc
	@for file in `find romfs/ -name *.a -o -name *.la`; do \
		rm $$file; \
	done
	-@rm romfs/lib/modules/$(KERNEL_VERSION)/build romfs/lib/modules/$(KERNEL_VERSION)/source
	@for file in `find romfs/lib/ -maxdepth 1 -type f`; do \
		$(CROSS_COMPILE)strip $$file; \
	done
	@touch $@

images/tinyroot.img: romfs/.stamp
	@mksquashfs romfs/* $@ -noappend -nopad -no-xattrs -comp lzo -all-root -b 128k

images/tinyroot.cpio.gz: romfs/.stamp
	@$(KERNEL_BUILD)/scripts/gen_initramfs_list.sh -u squash -g squash romfs > init.ramfs
	@cat tiny.ramfs init.ramfs | $(KERNEL_BUILD)/usr/gen_init_cpio - >images/tinyroot.cpio
	@gzip -f9 images/tinyroot.cpio

clean:
	@git clean -fdx

run:
	@./qemu.sh

rootfs: rootfs/etc/version

rootfs/etc/version:
	@for dir in boot dev etc/init.d proc sys mnt lib bin sbin tmp var run; do \
		mkdir -p rootfs/$$dir; \
	done
	@echo '#!/bin/sh' > rootfs/etc/init.d/rcS
	@chmod 0755 rootfs/etc/init.d/rcS
	@echo "/tmp	/tmp	tmpfs	size=4M,noatime,nodiratime,nosuid	0	0" >  rootfs/etc/fstab
	@echo "/var	/var	tmpfs	size=4M					0	0" >> rootfs/etc/fstab
	@mkdir -p images
	@echo `date` >$@

kernel: images/zImage

images/zImage: $(KERNEL)/.config rootfs/etc/version
	@$(MAKE) -C $(KERNEL)
	@INSTALL_PATH=../images make -C $(KERNEL) install
	@INSTALL_DTBS_PATH=../images make -C $(KERNEL) dtbs dtbs_install
	@INSTALL_MOD_PATH=../rootfs INSTALL_MOD_STRIP=--strip-unneeded make -C $(KERNEL) modules_install
	@cp $(KERNEL)/arch/arm/boot/zImage images/

$(KERNEL).tar.xz:
	@wget -O $@ https://cdn.kernel.org/pub/linux/kernel/v4.x/$@

$(KERNEL)/.config: $(KERNEL).tar.xz
	@tar xf $<
	@cp linux.config $@
	@$(MAKE) -C $(KERNEL) oldconfig

busybox: rootfs/bin/busybox

rootfs/bin/busybox: $(BUSYBOX)/.config rootfs/etc/version
	@$(MAKE) -C $(BUSYBOX)
	@$(MAKE) -C $(BUSYBOX) install

$(BUSYBOX)/.config: $(BUSYBOX).tar.bz2
	@tar xf $<
	@cp busybox.config $@
	@$(MAKE) -C $(BUSYBOX) oldconfig

$(BUSYBOX).tar.bz2:
	@wget -O $@ http://busybox.net/downloads/$@

libite: $(LIBITE)/.config

$(LIBITE)/.stamp: $(LIBITE)/.config
	@DESTDIR=$(CWD)/rootfs $(MAKE) -C $(dir $@) -j1 all install-strip
	@touch $@

$(LIBITE)/.config: $(LIBITE).tar.xz images/zImage rootfs/etc/version
	@tar xf $<
	@(cd $(dir $@) && ./configure --host=$(CROSS_TARGET) --prefix=)
	@touch $@

$(LIBITE).tar.xz:
	@wget -O $@ http://ftp.troglobit.com/libite/$@

libuev: $(LIBUEV)/.stamp

$(LIBUEV)/.stamp: $(LIBUEV)/.config
	@DESTDIR=$(CWD)/rootfs $(MAKE) -C $(dir $@) -j1 all install-strip
	@touch $@

$(LIBUEV)/.config: $(LIBUEV).tar.xz images/zImage rootfs/etc/version
	@tar xf $<
	@(cd $(dir $@) && ./configure --host=$(CROSS_TARGET) --prefix=)
	@touch $@

$(LIBUEV).tar.xz:
	@wget -O $@ http://ftp.troglobit.com/libuev/$@

finit: rootfs/sbin/finit

rootfs/sbin/finit: $(FINIT)/.stamp
	@cp finit.conf rootfs/etc/
	@ln -sf finit rootfs/sbin/init

$(FINIT)/.stamp: $(FINIT)/.config
	@DESTDIR=$(CWD)/rootfs $(MAKE) -C $(FINIT) -j1 all install-strip
	@touch $@

$(FINIT)/.config: $(FINIT).tar.xz $(LIBUEV)/.stamp $(LIBITE)/.stamp
	@tar xf $<
	@(cd $(FINIT) && ./configure --host=$(CROSS_TARGET) --prefix=	\
				--with-heading="tinyroot linux"		\
				--enable-fallback-shell			\
				--enable-watchdog)
	@touch $@

$(FINIT).tar.xz:
	@wget -O $@ http://ftp.troglobit.com/finit/$@

