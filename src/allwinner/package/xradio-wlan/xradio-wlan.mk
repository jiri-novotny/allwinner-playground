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

define XRADIO_WLAN_INSTALL_TARGET_CMDS
	if [ ! -d $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra ]; then \
		mkdir $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra; \
	fi
	cp $(@D)/xradio_wlan.ko \
	$(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra
	depmod -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
endef

$(eval $(generic-package))