#!/bin/sh

# Disable pulseaudio warning
export QEMU_AUDIO_DRV=none

# -initrd images/tinyroot.cpio.gz + root=/dev/rom0
qemu-system-arm -m 256M -M versatileab -rtc base=utc,clock=rt -nographic \
		-net bridge,br=virbr0 -net nic,model=smc91c111           \
		-kernel images/zImage  -dtb images/versatile-ab.dtb      \
		-initrd images/tinyroot.img                              \
		-append 'root=/dev/ram console=ttyAMA0 mem=256M quiet splash'
