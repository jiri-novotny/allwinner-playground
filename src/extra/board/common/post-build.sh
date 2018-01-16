#!/bin/sh

# store build time and info
echo USER=`uname -n` > ${TARGET_DIR}/etc/build
echo HOST_KERNEL_RELEASE=`uname -r` >> ${TARGET_DIR}/etc/build
echo HOST_KERNEL_VERSION=`uname -v` >> ${TARGET_DIR}/etc/build
echo BUILD_DATE=`date -R` >> ${TARGET_DIR}/etc/build

# buildroot extra tools
cp ${BUILD_DIR}/binutils*/binutils/objdump ${TARGET_DIR}/usr/bin
cp ${STAGING_DIR}/usr/lib/libopcodes-*.so ${TARGET_DIR}/usr/lib

# remove links from target fs
if [ -f ${TARGET_DIR}/linuxrc ]; then
  rm -rf ${TARGET_DIR}/linuxrc
fi

if [ -d ${TARGET_DIR}/lib32 ]; then
  rm -rf ${TARGET_DIR}/lib32
fi

if [ -d ${TARGET_DIR}/usr/lib32 ]; then
  rm -rf ${TARGET_DIR}/usr/lib32
fi

# remove triggerhappy config folder
if [ -d ${TARGET_DIR}/etc/triggerhappy ]; then
  rm -rf ${TARGET_DIR}/etc/triggerhappy
fi
