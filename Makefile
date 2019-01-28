###############################################################################
#
# Author: Jiri Novotny <jiri.novotny@logicelements.cz>
#
###############################################################################

# you can set buildroot source
BUILDROOT_USE_GIT=0
# you can set buildroot git version (branch or tag)
BUILDROOT_BRANCH=master
# you can set buildroot static version
BUILDROOT_RELEASE=buildroot-2018.11.1

# you current project name
PROJECT?=a13som_audio
DEFCONFIG?=$(PROJECT)_defconfig
DEPLOY_UBOOT_MBR?=0

# you can modify paths for target deployment
MOUNT_PATH=/mnt

# you probably dont want to change buildroot source url
BUILDROOT_GIT=git://git.buildroot.net/buildroot
BUILDROOT_URL=https://buildroot.org/downloads/$(BUILDROOT_RELEASE).tar.gz
TOOLCHAIN_RELEASE=gcc-linaro-6.5.0-2018.12-x86_64_arm-linux-gnueabihf
TOOLCHAIN_URL=https://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/arm-linux-gnueabihf/$(TOOLCHAIN_RELEASE).tar.xz
TOOLCHAIN64_RELEASE=gcc-linaro-6.5.0-2018.12-x86_64_aarch64-linux-gnu
TOOLCHAIN64_URL=https://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/aarch64-linux-gnu/$(TOOLCHAIN64_RELEASE).tar.xz

# dont edit after this line
BUILD_PATH=$(PROJECT)
EXTRA_PATH=extra
SRC_PATH=src

.PHONY: prepare

# Do not build "linux" by default since it is already built as part of Buildroot
all: prepare toolchain defconfig image

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

toolchain:
	if [ ! -d $(SRC_PATH)/toolchain ]; then \
		wget -O /tmp/toolchain.tar.xz $(TOOLCHAIN_URL); \
		tar xf /tmp/toolchain.tar.xz -C /tmp; \
		mv /tmp/$(TOOLCHAIN_RELEASE) $(SRC_PATH)/toolchain; \
	fi

toolchain64:
	if [ ! -d $(SRC_PATH)/toolchain64 ]; then \
		wget -O /tmp/toolchain64.tar.xz $(TOOLCHAIN64_URL); \
		tar xf /tmp/toolchain64.tar.xz -C /tmp; \
		mv /tmp/$(TOOLCHAIN64_RELEASE) $(SRC_PATH)/toolchain64; \
	fi

uboot:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) uboot

uboot_clean:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) uboot-dirclean

linux:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux

linux_clean:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux-dirclean

linux_config:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux-menuconfig
	cp $(BUILD_PATH)/build/`find $(BUILD_PATH)/build/linux-* -maxdepth 0 | grep -v -e headers -e firmware | cut -d "/" -f 3`/.config $(SRC_PATH)/$(EXTRA_PATH)/board/$(PROJECT)/kernel.cfg

linux_rebuild:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux-rebuild

linux_newbuild:
	rm -rf $(SRC_PATH)/buildroot/dl/`find $(BUILD_PATH)/build/linux-* -maxdepth 0 | grep -v -e headers -e firmware | cut -d "/" -f 3`.tar.gz
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux-dirclean
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) linux

image:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH)
	
config:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) menuconfig
	
defconfig:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) $(DEFCONFIG)

save:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) savedefconfig

clean:
	$(MAKE) BR2_EXTERNAL=../$(EXTRA_PATH) -C $(SRC_PATH)/buildroot O=../../$(BUILD_PATH) clean

distclean:
	rm -rf `find . -maxdepth 1 ! -path . -type d | grep -v -e Makefile -e README -e $(SRC_PATH) -e .git`

mrproper: distclean
	rm -rf $(SRC_PATH)/toolchain
	rm -rf $(SRC_PATH)/toolchain64
	rm -rf $(SRC_PATH)/buildroot

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
	if [ $(DEPLOY_UBOOT_MBR) -eq 1 ]; then \
		sudo cp $(BUILD_PATH)/images/u-boot-sunxi-with-spl.bin $(MOUNT_PATH)/boot; \
	fi
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

deploymx: image
ifdef DRIVE
	sudo mkfs.ext4 -F -L rootfs $(DRIVE)1
	sudo mount $(DRIVE)1 $(MOUNT_PATH)
	sudo tar -xf $(BUILD_PATH)/images/rootfs.tar -C $(MOUNT_PATH)
	sudo mkdir $(MOUNT_PATH)/boot
	sudo cp $(BUILD_PATH)/images/zImage $(MOUNT_PATH)/boot
	sudo cp $(BUILD_PATH)/images/*.dtb $(MOUNT_PATH)/boot
	sudo umount $(MOUNT_PATH)
else
	$(info Define DRIVE variable (e.g. DRIVE=/dev/sdc))
endif

copy: prepare image
ifdef TARGET
	if [ ! -d $(TARGET)/$(PROJECT) ]; then sudo mkdir $(TARGET)/$(PROJECT); fi
	sudo cp $(BUILD_PATH)/images/* $(TARGET)/$(PROJECT)
else
	$(info Define TARGET variable (e.g. TARGET=/mnt/))
endif

projects:
	# a13som_audio           - audio server on Olimex A13 SoM
	# espresso               - Marvell EspressoBin testing image
	# h2zero                 - Orange Pi Zero testing image
	# mxsystem               - MX testing image
	# raspi                  - Raspberry Pi 3 testing image
	#
	# Usage: PROJECT=h2zero make

help:
	# all                    - default rule for build, triggers prepare and buildroot
	# image                  - filesystem
	# clean                  - remove filesystem
	# config                 - start buildroot filesystem menuconfig
	# defconfig              - buildroot filesystem default config
	# savedefconfig          - save buildroot filesystem default config
	# linux                  - build linux separately
	# linux_clean            - clean linux
	# linux_config           - start linux menuconfig
	# linux_rebuild          - start linux rebuild
	# linux_newbuild         - start new (clean) linux build
	# prepare                - download all required resources
	# projects				 - list supported projects
	# install                - requires variable DRIVE, prepare partitions on DRIVE, optional DEPLOY_UBOOT_MBR
	# copy                   - requires variable TARGET, mounts TARGET and copy files
	# update                 - requires variable DRIVE, mounts DRIVE and updates kernel, dtb and modules
	# uboot                  - build uboot
	# uboot_clean            - clean uboot
