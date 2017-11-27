################################################################################
#
# xradio-wlan
#
################################################################################

XRADIO_WLAN_VERSION = b00ccb0e1524bf53e443fc5777df841b5db3c4e0
XRADIO_WLAN_SITE = $(call github,fifteenhex,xradio,$(XRADIO_WLAN_VERSION))
XRADIO_WLAN_LICENSE = GPLv2
XRADIO_WLAN_DEPENDENCIES = linux

define XRADIO_WLAN_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) ARCH=arm CROSS_COMPILE=$(TARGET_CROSS) \
	-C $(LINUX_DIR) M=$(@D)
endef

ifeq ($(BR2_XRADIO_WLAN_COPY_FW),y)
define XRADIO_WLAN_COPY_FW
	if [ ! -d $(TARGET_DIR)/lib/firmware ]; then \
		mkdir $(TARGET_DIR)/lib/firmware; \
	fi
	if [ ! -d $(TARGET_DIR)/lib/firmware/xr819 ]; then \
		mkdir $(TARGET_DIR)/lib/firmware/xr819; \
	fi
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/r16sdk/boot_B100.bin \
		$(TARGET_DIR)/lib/firmware/xr819/
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/r16sdk/etf_B100.bin \
		$(TARGET_DIR)/lib/firmware/xr819/etf_B100.bin
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/r16sdk/fw_B100.bin \
		$(TARGET_DIR)/lib/firmware/xr819/fw_B100.bin
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ALLWINNER_PATH)/package/xradio-wlan/firmware/r16sdk/sdd_B100.bin \
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
