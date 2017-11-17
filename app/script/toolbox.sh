#!/system/bin/sh

set -ex

chmod 0700 toolbox
./toolbox "$1" "$2"
