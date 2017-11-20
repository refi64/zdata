#!/system/bin/sh

set -ex
cd /data/data/com.refi64.zdata.app/app_flutter

[ -d "storage" ] || exit 0
export ZDATA_NORUN=1
cd storage
for dir in *; do
  sh /data/data/com.refi64.zdata.app/app_flutter/mount.sh "$dir"
done
