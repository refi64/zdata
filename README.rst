zdata
=====

A WIP project to let you compress the data used by Android apps, in order to save storage
space. Note that it requires a farily recent NDK version (at least r15).

Building
********

::
  $ toolchain/make_toolchain.sh
  $ libmagic-android/configure.sh
  $ libmagic-android/build.sh
  $ boost-android/download.sh
  $ boost-android/bootstrap.sh
  $ boost-android/build.sh  # it's OK if you get some errors here
  $ fs/build.sh
  $ app/build.sh
