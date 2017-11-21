NDK_TOOLCHAIN_VERSION := clang

APP_BUILD_SCRIPT := Android.mk
APP_PLATFORM := android-21
APP_MODULES := libfuse_static fusermount fusecompress toolbox
APP_STL := c++_static
APP_CPPFLAGS := -fexceptions -frtti
APP_ALLOW_MISSING_DEPS := true
