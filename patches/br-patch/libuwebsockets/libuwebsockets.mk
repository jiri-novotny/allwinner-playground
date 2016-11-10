################################################################################
#
# libuwebsockets
#
################################################################################

LIBUWEBSOCKETS_VERSION = 0.11.0
LIBUWEBSOCKETS_SOURCE = v$(LIBUWEBSOCKETS_VERSION).tar.gz
LIBUWEBSOCKETS_SITE = https://github.com/uWebSockets/uWebSockets/archive
LIBUWEBSOCKETS_INSTALL_STAGING = YES
LIBUWEBSOCKETS_DEPENDENCIES = libuv

ifeq ($(BR2_PACKAGE_LIBUWEBSOCKETS_EXAMPLES),y)
define LIBUWEBSOCKETS_INSTALL_TARGET_CMDS
	cp -dpf $(STAGING_DIR)/usr/lib/libuWS.so $(TARGET_DIR)/usr/lib
	$(INSTALL) -D -m 0755 $(@D)/examples/echo $(TARGET_DIR)/usr/sbin/websocketserver
endef
else
define LIBUWEBSOCKETS_INSTALL_TARGET_CMDS
	cp -dpf $(STAGING_DIR)/usr/lib/libuWS.so $(TARGET_DIR)/usr/lib
endef
endif

$(eval $(cmake-package))
