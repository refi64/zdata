NDK_TOOLCHAIN_VERSION := clang

APP_BUILD_SCRIPT := Android.mk
APP_PLATFORM := android-24
APP_MODULES := libfuse_static fusermount fusecompress getowner
APP_STL := c++_static
APP_CPPFLAGS := -fexceptions -frtti
APP_ALLOW_MISSING_DEPS := true
