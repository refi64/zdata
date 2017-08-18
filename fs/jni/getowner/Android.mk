LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := getowner
LOCAL_SRC_FILES := getowner.c
include $(BUILD_EXECUTABLE)
