#!/bin/sh

if [ -f ${BINARIES_DIR}/rootfs.ubifs ]; then
  rm ${BINARIES_DIR}/rootfs.ubifs
fi
