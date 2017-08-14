#!/system/bin/sh

set -ex

[ -n "$1" ] || exit 0
cd /data/data/com.refi64.zdata.app/app_flutter

user=`stat -c '%U' "/data/data/$1" | tr -d ' '`
pm clear "$1"
new=""
[ -d "$storage/$1" ] || new=1
mkdir -p "storage/$1"
chmod +x fusecompress
./fusecompress -o allow_other,nonempty,fc_c:zlib "storage/$1" "/data/data/$1"
[ -n "$new" ] || pm clear "$1"
chown -R "$user:$user" "/data/data/$1"

[ "$ZDATA_NORUN" = "1" ] && exit 0 ||:
am force-stop com.refi64.zdata.app
am start -W com.refi64.zdata.app/com.refi64.zdata.app.MainActivity
