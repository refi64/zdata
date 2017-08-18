#!/system/bin/sh

set -ex

[ -n "$1" ] || exit 0
cd /data/data/com.refi64.zdata.app/app_flutter

chmod 0700 fusecompress
chmod 0700 getowner

owner=`./getowner "/data/data/$1"`
pm clear "$1"
new=""
[ -d "$storage/$1" ] || new=1
mkdir -p "storage/$1"

./fusecompress -o allow_other,nonempty,fc_c:zlib "storage/$1" "/data/data/$1"
[ -n "$new" ] || pm clear "$1"
chown -R "$owner" "/data/data/$1"

[ "$ZDATA_NORUN" = "1" ] && exit 0 ||:
am force-stop com.refi64.zdata.app
am start -W com.refi64.zdata.app/com.refi64.zdata.app.MainActivity
