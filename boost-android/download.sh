#!/bin/bash

cd "`dirname "$0"`"

curl -Lo boost.tgz https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz
tar xvf boost.tgz --exclude="boost_1_64_0/doc"
mv boost_1_64_0 boost
rm boost.tgz
