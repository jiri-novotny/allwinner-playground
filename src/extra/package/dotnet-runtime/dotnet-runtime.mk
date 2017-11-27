################################################################################
#
# dotnet-runtime
#
################################################################################

DOTNET_RUNTIME_VERSION = 2.0.0
DOTNET_RUNTIME_SOURCE = dotnet-runtime-$(DOTNET_RUNTIME_VERSION)-linux-arm.tar.gz
DOTNET_RUNTIME_SITE_METHOD = file
DOTNET_RUNTIME_SITE = ${BR2_EXTERNAL_EXTRAS_PATH}/package/dotnet-runtime
DOTNET_RUNTIME_DEPENDENCIES = gettext libunwind lttng-ust openssl libcurl icu

define DOTNET_RUNTIME_BUILD_CMDS
	echo Done
endef

define DOTNET_RUNTIME_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/dotnet
	cp -dpfR $(@D)/* $(TARGET_DIR)/usr/share/dotnet
	ln -sf ../share/dotnet/dotnet $(TARGET_DIR)/usr/bin/dotnet
endef

$(eval $(generic-package))
