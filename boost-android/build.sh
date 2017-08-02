#!/bin/bash

cd "`dirname "$0"`"
toolchain="$PWD/../toolchain/toolchain"

cd boost

cat > clang-android.jam <<EOF
using clang : android : $toolchain/bin/clang++ :
    <cxxflags>-stdlib=libc++
    <cxxflags>-I$toolchain/include/c++/4.9.x ;
EOF

./b2 -j4 --user-config=clang-android.jam \
    toolset=clang-android \
    threading=multi \
    threadapi=pthread \
    link=static \
    runtime-link=static \
    target-os=linux
