#!/bin/bash

if [ -d ${BUILD_DIR}/linux-firmware-* ]; then
    rm -rf ${BUILD_DIR}/linux-firmware-*
fi

if [ -d ${TARGET_DIR}/lib/firmware ]; then
    rm -rf ${TARGET_DIR}/lib/firmware
fi
