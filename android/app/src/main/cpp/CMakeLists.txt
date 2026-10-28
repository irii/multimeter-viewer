# Builds libusb as libusb-1.0.so for every ABI of the APK. The Dart side
# loads it with DynamicLibrary.open('libusb-1.0.so').
#
# Mirrors libusb's own android/jni/libusb.mk. libusb is LGPL-2.1, see
# libusb-1.0.30/COPYING; it is built unmodified and as a separate shared
# library.
cmake_minimum_required(VERSION 3.22.1)
project(multimeter_viewer_libusb C)

set(LIBUSB_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/libusb-1.0.30)

add_library(usb-1.0 SHARED
  ${LIBUSB_ROOT}/libusb/core.c
  ${LIBUSB_ROOT}/libusb/descriptor.c
  ${LIBUSB_ROOT}/libusb/hotplug.c
  ${LIBUSB_ROOT}/libusb/io.c
  ${LIBUSB_ROOT}/libusb/sync.c
  ${LIBUSB_ROOT}/libusb/strerror.c
  ${LIBUSB_ROOT}/libusb/os/linux_usbfs.c
  ${LIBUSB_ROOT}/libusb/os/events_posix.c
  ${LIBUSB_ROOT}/libusb/os/threads_posix.c
  ${LIBUSB_ROOT}/libusb/os/linux_netlink.c
)

target_include_directories(usb-1.0 PRIVATE
  ${LIBUSB_ROOT}/android
  ${LIBUSB_ROOT}/libusb
  ${LIBUSB_ROOT}/libusb/os
)

target_compile_options(usb-1.0 PRIVATE -fvisibility=hidden -pthread)
target_link_libraries(usb-1.0 log)

# 16 KB page alignment, required for apps targeting Android 15+.
target_link_options(usb-1.0 PRIVATE "-Wl,-z,max-page-size=16384")
