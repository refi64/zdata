#!/bin/sh
set -e
cd "`dirname "$0"`"
ndk-build -C jni \
    APP_BUILD_SCRIPT=Android.mk \
    APP_PLATFORM=android-21 \
    APP_ABI=armeabi-v7a \
    APP_ALLOW_MISSING_DEPS=true "$@"
