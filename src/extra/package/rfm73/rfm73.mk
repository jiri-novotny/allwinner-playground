################################################################################
#
# rfm73
#
################################################################################

RFM73_VERSION = 059e876732d5e87da37781157d21c474e74a4955
RFM73_SITE = $(call github,jiri-novotny,rfm73-linux,$(RFM73_VERSION))
RFM73_LICENSE = MIT
RFM73_LICENSE_FILES = LICENSE
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
