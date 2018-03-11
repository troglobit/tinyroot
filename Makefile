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
export CPPFLAGS LDFLAGS

# pkg-config
PKG_CONFIG_LIBDIR := $(CWD)/rootfs/lib/pkgconfig
export PKG_CONFIG_LIBDIR

all: rootfs kernel busybox finit tinyroot

tinyroot:
	@$(CROSS_COMPILE)populate -f -s rootfs -d romfs
	@$(KERNEL_BUILD)/scripts/gen_initramfs_list.sh -u squash -g squash romfs > init.ramfs
	@cat tiny.ramfs init.ramfs | $(KERNEL_BUILD)/usr/gen_init_cpio - >images/tinyroot.cpio
	@gzip -f9 images/tinyroot.cpio

clean:
	@git clean -fdx

run:
	@./qemu.sh

rootfs:
	@for dir in boot dev etc/init.d proc sys mnt lib bin sbin var run; do \
		mkdir -p rootfs/$$dir; \
	done
	@echo '#!/bin/sh' > rootfs/etc/init.d/rcS
	@chmod 0755 rootfs/etc/init.d/rcS
	@mkdir images

kernel: $(KERNEL)
	@$(MAKE) -C $<
	@INSTALL_PATH=../images make -C $< install
	@cp $</arch/arm/boot/zImage images/
	@INSTALL_DTBS_PATH=../images make -C $< dtbs dtbs_install
	@INSTALL_MOD_PATH=../rootfs INSTALL_MOD_STRIP=--strip-all make -C $< modules_install

$(KERNEL).tar.xz:
	@wget -O $@ https://cdn.kernel.org/pub/linux/kernel/v4.x/$@

$(KERNEL): $(KERNEL).tar.xz
	@tar xf $<
	@cp linux.config $@
	@$(MAKE) -C $< oldconfig

busybox: $(BUSYBOX)
	@$(MAKE) -C $<
	@$(MAKE) -C $< install

$(BUSYBOX): $(BUSYBOX).tar.bz2
	@tar xf $<
	@cp busybox.config $@
	@$(MAKE) -C $< oldconfig

$(BUSYBOX).tar.bz2:
	@wget -O $@ http://busybox.net/downloads/$@

libite: $(LIBITE)
	@DESTDIR=$(shell pwd)/rootfs $(MAKE) -C $< all install-strip

$(LIBITE): $(LIBITE).tar.xz
	@tar xf $<
	@(cd $@ && ./configure --host=$(CROSS_TARGET) --prefix=)

$(LIBITE).tar.xz:
	@wget -O $@ http://ftp.troglobit.com/libite/$@

libuev: $(LIBUEV)
	@DESTDIR=$(shell pwd)/rootfs $(MAKE) -C $< all install-strip

$(LIBUEV): $(LIBUEV).tar.xz
	@tar xf $<
	@(cd $@ && ./configure --host=$(CROSS_TARGET) --prefix=)

$(LIBUEV).tar.xz:
	@wget -O $@ http://ftp.troglobit.com/libuev/$@

finit: $(FINIT)
	@DESTDIR=$(shell pwd)/rootfs $(MAKE) -C $< all install-strip
	@cp finit.conf rootfs/etc/
	@ln -sf finit rootfs/sbin/init

$(FINIT): $(LIBUEV) $(LIBITE) $(FINIT).tar.xz
	@tar xf $<
	@(cd $@ && ./configure --host=$(CROSS_TARGET) --prefix= --enable-fallback-shell --enable-watchdog)

$(FINIT).tar.xz:
	@wget -O $@ http://ftp.troglobit.com/finit/$@

