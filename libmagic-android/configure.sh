#!/bin/bash

cd "`dirname "$0"`"
toolchain="$PWD/../toolchain/toolchain"

cd file
autoreconf -fi
./configure \
    --enable-zlib --enable-static --disable-shared --host=arm-linux-androideabi \
    CC="$toolchain/bin/clang"
