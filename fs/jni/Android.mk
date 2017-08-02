LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

include $(LOCAL_PATH)/external/fuse/lib/Android.mk \
		$(LOCAL_PATH)/fusermount.mk \
        $(LOCAL_PATH)/fusecompress.mk
