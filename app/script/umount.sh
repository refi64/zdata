#!/system/bin/sh

set -ex

[ -n "$1" ] || exit 1
cd /data/data/com.refi64.zdata.app/app_flutter

chmod 0700 fusermount
./fusermount -u "/data/data/$1" ||:
pm clear "$1" ||:
rm -rf "storage/$1" ||:

svc power reboot ||:
