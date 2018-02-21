################################################################################
#
# nrf24
#
################################################################################

NRF24_VERSION = d64568a450c31ddf0cb2ae374c8892f8d2d229d7
NRF24_SITE = $(call github,wolfle,nrf24,$(NRF24_VERSION))
NRF24_LICENSE = GPLv3
NRF24_DEPENDENCIES = linux

define NRF24_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) ARCH=arm CROSS_COMPILE=$(TARGET_CROSS) \
	-C $(LINUX_DIR) M=$(@D)
endef

define NRF24_INSTALL_TARGET_CMDS
	if [ ! -d $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra ]; then \
		mkdir $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra; \
	fi
	cp $(@D)/nrf24.ko \
	$(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra
	depmod -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
endef

$(eval $(generic-package))
