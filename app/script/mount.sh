#!/system/bin/sh

set -ex

[ -n "$1" ] || exit 1
cd /data/data/com.refi64.zdata.app/app_flutter

pm clear "$1"
rm -rf "storage/$1"
mkdir -p "storage/$1"
chmod +x fusecompress
./fusecompress -o allow_other,nonempty "storage/$1" "/data/data/$1"

am force-stop com.refi64.zdata.app
am start -W com.refi64.zdata.app/com.refi64.zdata.app.MainActivity
