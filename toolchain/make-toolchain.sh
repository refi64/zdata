#!/bin/bash

cd "`dirname "$0"`"

ndk_build="`which ndk-build`"
ndk="`dirname "$ndk_build"`"

rm -rf toolchain
"$ndk/build/tools/make_standalone_toolchain.py" \
    --unified-headers --arch arm --api 24 --stl libc++ --install-dir=toolchain
