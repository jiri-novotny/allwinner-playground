################################################################################
#
# rfm73
#
################################################################################

RFM73_VERSION = 1.0
RFM73_SOURCE = rfm73-$(RFM73_VERSION).tar.gz
RFM73_SITE_METHOD = file
RFM73_SITE = ${BR2_EXTERNAL_EXTRAS_PATH}/package/rfm73
RFM73_DEPENDENCIES = linux

define RFM73_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) ARCH=$(ARCH) CROSS_COMPILE=$(TARGET_CROSS) \
	-C $(LINUX_DIR) M=$(@D)
endef

define RFM73_INSTALL_TARGET_CMDS
	if [ ! -d $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra ]; then \
		mkdir $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra; \
	fi
	cp $(@D)/rf-rfm73.ko \
	$(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra
	depmod -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
endef

$(eval $(generic-package))
