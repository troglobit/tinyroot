#!/bin/sh

# Disable pulseaudio warning
export QEMU_AUDIO_DRV=none

qemu-system-arm -m 256M -M versatilepb -rtc base=utc,clock=rt -nographic \
		-net bridge,br=virbr0 -net nic,model=smc91c111           \
		-kernel images/zImage  -dtb images/versatile-pb.dtb      \
		-initrd images/tinyroot.cpio.gz                          \
		-append 'root=/dev/rom0 console=ttyAMA0 mem=256M'
