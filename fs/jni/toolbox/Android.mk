LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := toolbox
LOCAL_SRC_FILES := toolbox.c
include $(BUILD_EXECUTABLE)
