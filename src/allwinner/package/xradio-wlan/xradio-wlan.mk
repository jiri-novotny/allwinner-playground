################################################################################
#
# xradio-wlan
#
################################################################################

XRADIO_WLAN_VERSION = 014dfdd203102c5fd2370a73ec4ae3e6dd4e9ded
XRADIO_WLAN_SITE = $(call github,fifteenhex,xradio,$(XRADIO_WLAN_VERSION))
XRADIO_WLAN_LICENSE = GPLv2
XRADIO_WLAN_DEPENDENCIES = linux

define XRADIO_WLAN_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) ARCH=arm CROSS_COMPILE=$(TARGET_CROSS) \
	-C $(LINUX_DIR) M=$(@D)
endef

ifneq ($(BR2_XRADIO_WLAN_COPY_FW),y)
define XRADIO_WLAN_COPY_FW
	if [ ! -d $(TARGET_DIR)/lib/firmware ]; then \
		mkdir $(TARGET_DIR)/lib/firmware; \
	fi
	if [ ! -d $(TARGET_DIR)/lib/firmware/xr819 ]; then \
		mkdir $(TARGET_DIR)/lib/firmware/xr819; \
	fi
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/boot_B100.bin \
		$(TARGET_DIR)/lib/firmware/xr819/
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/etf_B100.bin \
		$(TARGET_DIR)/lib/firmware/xr819/etf_B100.bin
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/fw_B100.bin \
		$(TARGET_DIR)/lib/firmware/xr819/fw_B100.bin
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/sdd_B100.bin \
		$(TARGET_DIR)/lib/firmware/xr819/sdd_B100.bin
endef
XRADIO_WLAN_POST_INSTALL_TARGET_HOOKS += XRADIO_WLAN_COPY_FW
endif

define XRADIO_WLAN_INSTALL_TARGET_CMDS
	if [ ! -d $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra ]; then \
		mkdir $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra; \
	fi
	cp $(@D)/xradio_wlan.ko \
	$(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra
	depmod -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
endef

$(eval $(generic-package))
