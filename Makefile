###############################################################################
#
# Author: Jiri Novotny <jiri.novotny@logicelements.cz>
#
###############################################################################

# you can set buildroot source
BUILDROOT_USE_GIT=0
# you can set buildroot git version (branch or tag)
BUILDROOT_BRANCH=2016.11.x
# you can set buildroot static version
BUILDROOT_RELEASE=buildroot-2016.11.2

# you current project name
CURRENT_PROJECT=h2zero
CURRENT_DEFCONFIG=$(CURRENT_PROJECT)_defconfig

# you can modify paths for target deployment
SD_PATH=/mnt

# you probably dont want to change buildroot source url
BUILDROOT_GIT=git://git.buildroot.net/buildroot
BUILDROOT_URL=https://buildroot.org/downloads/$(BUILDROOT_RELEASE).tar.gz

# dont edit after this line
BUILD_PATH=$(CURRENT_PROJECT)
EXTRA_PATH=allwinner
SRC_PATH=src
BASE_PATH=$(shell pwd)

.PHONY: prepare audio

# Do not build "linux" by default since it is already built as part of Buildroot
all: prepare buildroot_defconfig buildroot

prepare:
	if [ ! -d $(SRC_PATH)/buildroot ]; then \
		if [ $(BUILDROOT_USE_GIT) -eq 0 ]; then \
			wget -O /tmp/buildroot.tar.gz $(BUILDROOT_URL); \
			tar zxf /tmp/buildroot.tar.gz -C /tmp; \
			mv /tmp/$(BUILDROOT_RELEASE) $(SRC_PATH)/buildroot; \
		else \
			git clone -b $(BUILDROOT_BRANCH) $(BUILDROOT_GIT) $(SRC_PATH)/buildroot; \
		fi; \
	fi

uboot:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) uboot

linux:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux

linux_config:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux-menuconfig

linux_rebuild:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux-rebuild

$(CURRENT_PROJECT): buildroot
$(CURRENT_PROJECT)_config: buildroot_config
$(CURRENT_PROJECT)_defconfig: buildroot_defconfig
$(CURRENT_PROJECT)_savedefconfig: buildroot_savedefconfig
$(CURRENT_PROJECT)_clean: buildroot_clean

buildroot:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH)
	
buildroot_config:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) menuconfig
	
buildroot_defconfig:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) $(CURRENT_DEFCONFIG)

buildroot_savedefconfig:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) savedefconfig

buildroot_clean:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) clean

install: prepare uboot buildroot
ifdef DRIVE
	# Deploy image
	echo -e "d\n\nd\n\nd\n\nd\no\n\nn\np\n1\n8192\n\n\nw\n" | sudo fdisk $(DRIVE)
	sudo dd if=$(AUDIO_PATH)/images/u-boot-sunxi-with-spl.bin of=${DRIVE} bs=1024 seek=8
	sudo mkfs.ext4 -F -L rootfs $(DRIVE)1
	sudo mount $(DRIVE)1 $(MOUNT_PATH)
	sudo tar -xf $(AUDIO_PATH)/images/rootfs.tar -C $(MOUNT_PATH)
	sudo umount $(MOUNT_PATH)
else
	$(info Define DRIVE variable (e.g. DRIVE=/dev/sdx))
endif

update: buildroot
ifdef DRIVE
	# Deploy new kernel and modules
	sudo mount $(DRIVE)1 $(SD_PATH)
	sudo rm -rf $(SD_PATH)/boot/*
	sudo rm -rf $(SD_PATH)/lib/modules/*
	sudo cp $(BUILD_PATH)/images/zImage $(SD_PATH)/boot
	sudo cp $(BUILD_PATH)/images/*.dtb $(SD_PATH)/boot
	sudo tar -C $(SD_PATH) -xf $(BUILD_PATH)/images/rootfs.tar ./lib/modules
	sudo umount $(SD_PATH)
else
	$(info Define DRIVE variable (e.g. DRIVE=/dev/sdc))
endif

copy: prepare uboot buildroot
ifdef TARGET
	if [ ! -d $(TARGET)/$(PROJECT_NAME) ]; then sudo mkdir $(TARGET)/$(PROJECT_NAME); fi
	sudo cp $(BUILD_PATH)/images/* $(TARGET)/$(PROJECT_NAME)
else
	$(info Define TARGET variable (e.g. TARGET=/mnt/))
endif

help:
	# all                        - default rule for build, triggers prepare and buildroot
	# buildroot	                 - filesystem
	# buildroot_clean            - remove filesystem
	# buildroot_config		     - start buildroot filesystem menuconfig
	# buildroot_defconfig        - buildroot filesystem default config
	# buildroot_savedefconfig    - save buildroot filesystem default config
	# linux                      - build linux separately
	# linux_config               - start linux menuconfig
	# linux_rebuild              - start linux rebuild
	# prepare                    - init submodules and download all required resources
	# recovery                   - build recovery filesystem
	# recovery_clean             - clean recovery filesystem
	# recovery_config            - menuconfig for recovery filesystem
	# install                    - requires variable DRIVE, prepare partitions on DRIVE
	# copy                       - requires variable TARGET, mounts TARGET and copy files
	# update                     - requires variable DRIVE, mounts DRIVE and updates kernel, dtb and modules
	# uboot                      - build uboot
