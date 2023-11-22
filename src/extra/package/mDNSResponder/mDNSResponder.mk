################################################################################
#
# mDNSResponder
#
################################################################################

MDNSRESPONDER_VERSION = 1310.40.42
MDNSRESPONDER_SOURCE = mDNSResponder-$(MDNSRESPONDER_VERSION).tar.gz
MDNSRESPONDER_SITE = https://opensource.apple.com/tarballs/mDNSResponder
MDNSRESPONDER_LICENSE = Apache 2.0
MDNSRESPONDER_INSTALL_STAGING = YES

define MDNSRESPONDER_BUILD_CMDS
	$(TARGET_MAKE_ENV) CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	CC="$(TARGET_CC)" \
	LD="$(TARGET_LD) -shared" \
	STRIP="$(TARGET_STRIP) -S" \
	BISON="$(HOST_DIR)/bin/bison" \
	FLEX="$(HOST_DIR)/bin/flex" \
	$(MAKE1) os=buildroot -C $(@D)/mDNSPosix
endef

define MDNSRESPONDER_INSTALL_STAGING_CMDS
	cp -dpfr $(@D)/mDNSShared/dns_sd.h $(STAGING_DIR)/usr/include
	cp -dpfr $(@D)/mDNSPosix/build/prod/libdns_sd.so $(STAGING_DIR)/usr/lib
endef

define MDNSRESPONDER_INSTALL_TARGET_CMDS
	cp -dpfr $(@D)/mDNSPosix/build/prod/libdns_sd.so $(TARGET_DIR)/usr/lib
	cp -dpfr $(@D)/mDNSPosix/build/prod/mdnsd $(TARGET_DIR)/usr/sbin
	cp -dpfr $(@D)/Clients/build/dns-sd $(TARGET_DIR)/usr/sbin
	cp -dpfr $(BR2_EXTERNAL_EXTRAS_PATH)/package/mDNSResponder/S42mDNSResponder $(TARGET_DIR)/etc/init.d
endef

$(eval $(generic-package))
