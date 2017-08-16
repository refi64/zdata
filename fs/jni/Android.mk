LOCAL_PATH := $(call my-dir)

ifeq ($(APP_ABI),armeabi-v7a)
	ARCH=arm
else ifeq ($(APP_ABI),x86)
	ARCH=x86
else
	$(error Invalid ABI $(APP_ABI))
endif

include $(CLEAR_VARS)

include $(LOCAL_PATH)/external/fuse/lib/Android.mk \
        $(LOCAL_PATH)/fusermount.mk \
        $(LOCAL_PATH)/fusecompress.mk
