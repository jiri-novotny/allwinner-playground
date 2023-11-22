################################################################################
#
# mdnsd
#
################################################################################

MDNSD_VERSION = 1310.40.42
MDNSD_SOURCE = mDNSResponder-$(MDNSD_VERSION).tar.gz
MDNSD_SITE = https://opensource.apple.com/tarballs/mDNSResponder
MDNSD_LICENSE = Apache 2.0
MDNSD_INSTALL_STAGING = YES

define MDNSD_BUILD_CMDS
	$(TARGET_MAKE_ENV) CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	CC="$(TARGET_CC)" \
	LD="$(TARGET_LD) -shared" \
	STRIP="$(TARGET_STRIP) -S" \
	BISON="$(HOST_DIR)/bin/bison" \
	FLEX="$(HOST_DIR)/bin/flex" \
	$(MAKE1) os=buildroot -C $(@D)/mDNSPosix
endef

define MDNSD_INSTALL_STAGING_CMDS
	cp -dpfr $(@D)/mDNSShared/dns_sd.h $(STAGING_DIR)/usr/include
	cp -dpfr $(@D)/mDNSPosix/build/prod/libdns_sd.so $(STAGING_DIR)/usr/lib
endef

define MDNSD_INSTALL_TARGET_CMDS
	cp -dpfr $(@D)/mDNSPosix/build/prod/libdns_sd.so $(TARGET_DIR)/usr/lib
	cp -dpfr $(@D)/mDNSPosix/build/prod/mdnsd $(TARGET_DIR)/usr/sbin
	cp -dpfr $(@D)/Clients/build/dns-sd $(TARGET_DIR)/usr/sbin
	cp -dpfr $(BR2_EXTERNAL_EXTRAS_PATH)/package/mdnsd/S42mdnsd $(TARGET_DIR)/etc/init.d
endef

$(eval $(generic-package))
