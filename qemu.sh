#!/bin/sh

# Disable pulseaudio warning
export QEMU_AUDIO_DRV=none

qemu-system-arm -m 256M -M versatilepb -nographic \
		-kernel images/zImage \
		-append 'root=/dev/rom0 console=ttyAMA0 mem=256M' \
		-dtb images/versatile-pb.dtb \
		-initrd images/tinyroot.cpio.gz
		
