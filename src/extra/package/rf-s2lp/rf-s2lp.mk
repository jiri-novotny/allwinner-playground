################################################################################
#
# rf-s2lp
#
################################################################################

RF_S2LP_VERSION = 0.0.20
RF_S2LP_SOURCE = rf-s2lp-$(RF_S2LP_VERSION).tar
RF_S2LP_SITE_METHOD = file
RF_S2LP_SITE = ${BR2_EXTERNAL_EXTRAS_PATH}/package/rf-s2lp
RF_S2LP_LICENSE = GPLv2
RF_S2LP_DEPENDENCIES = linux

define RF_S2LP_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) ARCH=arm CROSS_COMPILE=$(TARGET_CROSS) \
	-C $(LINUX_DIR) M=$(@D)
endef

define RF_S2LP_INSTALL_TARGET_CMDS
	if [ ! -d $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra ]; then \
		mkdir $(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra; \
	fi
	cp $(@D)/rf-s2lp.ko \
	$(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/extra
	depmod -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
endef

$(eval $(generic-package))