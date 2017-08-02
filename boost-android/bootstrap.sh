#!/bin/bash

cd "`dirname "$0"`"

cd boost
./bootstrap.sh --with-toolset=clang
