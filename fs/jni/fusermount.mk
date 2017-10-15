LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := fusermount
LOCAL_SRC_FILES := \
	external/fuse/util/fusermount.c \
	external/fuse/lib/mount_util.c
LOCAL_C_INCLUDES := \
	external/fuse/android \
	external/fuse/include \
	external/fuse/lib
# Android doesn't have lockf
LOCAL_CFLAGS := \
	-include sys/file.h \
	-D_FILE_OFFSET_BITS=64 \
	-DF_LOCK=LOCK_EX \
	-DF_ULOCK=LOCK_UN \
	-D"lockf(fd,cmd,len)=flock(fd,cmd)"
include $(BUILD_EXECUTABLE)
