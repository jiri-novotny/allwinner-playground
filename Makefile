###############################################################################
#
# Author: Jiri Novotny <jiri.novotny@logicelements.cz>
#
###############################################################################

# you can set buildroot source
BUILDROOT_USE_GIT=1
# you can set buildroot git version (branch or tag)
BUILDROOT_BRANCH=master
# you can set buildroot static version
BUILDROOT_RELEASE=buildroot-2017.02.2

# you current project name
CURRENT_PROJECT?=h2zero
CURRENT_DEFCONFIG?=$(CURRENT_PROJECT)_defconfig
DEPLOY_UBOOT_MBR?=0

# you can modify paths for target deployment
MOUNT_PATH=/mnt

# you probably dont want to change buildroot source url
BUILDROOT_GIT=git://git.buildroot.net/buildroot
BUILDROOT_URL=https://buildroot.org/downloads/$(BUILDROOT_RELEASE).tar.gz

# dont edit after this line
BUILD_PATH=$(CURRENT_PROJECT)
EXTRA_PATH=allwinner
SRC_PATH=src

.PHONY: prepare

# Do not build "linux" by default since it is already built as part of Buildroot
all: prepare defconfig image

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

image:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH)
	
config:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) menuconfig
	
defconfig:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) $(CURRENT_DEFCONFIG)

savedefconfig:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) savedefconfig

clean:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) clean

install: prepare image
ifdef DRIVE
	# Deploy image
	echo -e "d\n\nd\n\nd\n\nd\no\n\nn\np\n1\n8192\n\n\nw\n" | sudo fdisk $(DRIVE)
	if [ $(DEPLOY_UBOOT_MBR) -eq 1 ]; then \
		sudo dd if=$(BUILD_PATH)/images/u-boot-sunxi-with-spl.bin of=$(DRIVE) bs=1024 seek=8; \
	fi
	sleep 1
	sudo mkfs.ext4 -F -L rootfs $(DRIVE)1
	sudo mount $(DRIVE)1 $(MOUNT_PATH)
	sudo tar -xf $(BUILD_PATH)/images/rootfs.tar -C $(MOUNT_PATH)
	sudo cp $(BUILD_PATH)/images/u-boot-sunxi-with-spl.bin $(MOUNT_PATH)/boot
	sudo umount $(MOUNT_PATH)
else
	$(info Define DRIVE variable (e.g. DRIVE=/dev/sdx))
endif

update: image
ifdef DRIVE
	# Deploy new kernel and modules
	sudo mount $(DRIVE)1 $(MOUNT_PATH)
	sudo rm -rf $(MOUNT_PATH)/boot/*
	sudo rm -rf $(MOUNT_PATH)/lib/modules/*
	sudo cp $(BUILD_PATH)/images/zImage $(MOUNT_PATH)/boot
	sudo cp $(BUILD_PATH)/images/*.dtb $(MOUNT_PATH)/boot
	sudo tar -C $(MOUNT_PATH) -xf $(BUILD_PATH)/images/rootfs.tar ./lib/modules
	sudo umount $(MOUNT_PATH)
else
	$(info Define DRIVE variable (e.g. DRIVE=/dev/sdc))
endif

copy: prepare image
ifdef TARGET
	if [ ! -d $(TARGET)/$(PROJECT_NAME) ]; then sudo mkdir $(TARGET)/$(PROJECT_NAME); fi
	sudo cp $(BUILD_PATH)/images/* $(TARGET)/$(PROJECT_NAME)
else
	$(info Define TARGET variable (e.g. TARGET=/mnt/))
endif

help:
	# all                        - default rule for build, triggers prepare and buildroot
	# image                      - filesystem
	# clean                      - remove filesystem
	# config                     - start buildroot filesystem menuconfig
	# defconfig                  - buildroot filesystem default config
	# savedefconfig              - save buildroot filesystem default config
	# linux                      - build linux separately
	# linux_config               - start linux menuconfig
	# linux_rebuild              - start linux rebuild
	# prepare                    - download all required resources
	# install                    - requires variable DRIVE, prepare partitions on DRIVE
	# copy                       - requires variable TARGET, mounts TARGET and copy files
	# update                     - requires variable DRIVE, mounts DRIVE and updates kernel, dtb and modules
	# uboot                      - build uboot
