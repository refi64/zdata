# (flags and sources taken from fusecompress/src/Makefile.am)

LOCAL_PATH := $(call my-dir)
BOOST_ANDROID_ROOT := $(LOCAL_PATH)/../../boost-android/boost
BOOST_ANDROID_LIBS := $(LOCAL_PATH)/../../boost-android/boost/$(ARCH)/stage/lib
LIBMAGIC_ANDROID := $(LOCAL_PATH)/../../libmagic-android/$(ARCH)/src

common_sources := \
	boost/iostreams/filter/lzma.cpp \
	CompressionType.cpp \
	FileHeader.cpp \
	CompressedMagic.cpp \
	FileRememberTimes.cpp \
	FileRememberXattrs.cpp \
	FuseCompress.cpp \
	File.cpp \
	FileUtils.cpp \
	Compress.cpp \
	Memory.cpp \
	FileManager.cpp \
	Block.cpp \
	LayerMap.cpp \
	LinearMap.cpp

common_sources := $(addprefix fusecompress/src/,$(common_sources))

common_c_includes := \
	$(LOCAL_PATH)/external/fuse/include \
	$(LOCAL_PATH)/external/lzma/C \
	$(BOOST_ANDROID_ROOT) \
	$(LIBMAGIC_ANDROID) \
	fusecompress/src

common_cppflags := \
	-DASSERT_H \
	-D"assert(expr)=((expr)?(void)0:abort())" \
	-D_FILE_OFFSET_BITS=64 \
	-DFUSE_USE_VERSION=26 \
	-D_GNU_SOURCE \
	-D_REENTRANT \
	-D_POSIX_C_SOURCE=200112L \
	-D_POSIX_SOURCE \
	-D_DEFAULT_SOURCE \
	-D_XOPEN_SOURCE=500 \
	-Wno-long-long \
	-Wall \
	-fpermissive

include $(CLEAR_VARS)
LOCAL_MODULE := fusecompress
LOCAL_SRC_FILES := \
	$(common_sources) \
	fusecompress/src/main.cpp
LOCAL_C_INCLUDES := $(common_c_includes)
# The fgetpos and fsetpos defines are to work around some odd libc++ compile errors
LOCAL_CPPFLAGS := $(common_cppflags)
LOCAL_STATIC_LIBRARIES := libfuse_static
LOCAL_LDLIBS := \
	-L$(BOOST_ANDROID_LIBS) \
	-L$(LIBMAGIC_ANDROID) \
	-lboost_serialization \
	-lboost_iostreams \
	-lboost_program_options \
	-lboost_filesystem \
	-lboost_system \
	-lmagic \
	-lz
include $(BUILD_EXECUTABLE)
