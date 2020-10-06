#!/bin/sh

if [ -f ${LINUX_DIR}/arch/arm/boot/dts/suniv-f1c100s-licheepi-nano.dtb ]; then
  cp ${LINUX_DIR}/arch/arm/boot/dts/suniv-f1c100s-licheepi-nano.dtb ${BINARIES_DIR}
else
  cp ${BUILD_DIR}/linux-5.9-rc6/arch/arm/boot/dts/suniv-f1c100s-licheepi-nano.dtb ${BINARIES_DIR}  
fi

cp ${BINARIES_DIR}/suniv-f1c100s-licheepi-nano.dtb ${TARGET_DIR}/boot
