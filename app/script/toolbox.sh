#!/system/bin/sh

set -ex

[ -n "$1" ] && [ -n "$2" ] || exit 1
cd /data/data/com.refi64.zdata.app/app_flutter

chmod 0700 toolbox
./toolbox "$1" "$2"
