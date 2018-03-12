tinyroot
========

There are two ways to build, the preferred way uses `make` and the
portable, but less maintained, is a simple shell script:

    make -j5
	make run

or,

    ./bootstrap.sh


requirements
------------

You need a crosstool-NG based toolchain, get one for free at
http://ftp.troglobit.com/pub/Toolchains/

- arm-unknown-linux-gnueabi-gcc
- libssl-dev
- mksquashfs
- wget
- tar, gzip
- make
- qemu

--  
Joachim
