#!/bin/bash

cd "`dirname "$0"`"
toolchain="$PWD/../toolchain/toolchain"

cd xz
./autogen.sh
./configure \
    --enable-static --disable-shared --host=arm-linux-androideabi \
    CC="$toolchain/bin/clang"
rm m4/extern-inline.m4
