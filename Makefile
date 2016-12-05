# you can set project name
PROJECT_NAME=a13
# you can set buildroot source
BUILDROOT_USE_GIT=0
# you can set buildroot git version (branch or tag)
BUILDROOT_BRANCH=master
# you can set buildroot static version
BUILDROOT_RELEASE=buildroot-2016.11

# project variable
AUDIO_PATH=./audio
KERNEL_PATH=$(AUDIO_PATH)/build/linux-4.9-rc3

# you probably dont want to change buildroot source url
BUILDROOT_GIT=git://git.buildroot.net/buildroot
BUILDROOT_URL=https://buildroot.org/downloads/$(BUILDROOT_RELEASE).tar.gz

# dont edit after this line
SRC_PATH=./buildroot
PATCH_PATH=./patches
MOUNT_PATH=/mnt

.PHONY: prepare audio

all: prepare audio

prepare:
	if [ ! -d $(SRC_PATH) ]; then \
		if [ $(BUILDROOT_USE_GIT) -eq 0 ]; then \
			wget -O /tmp/buildroot.tar.gz $(BUILDROOT_URL) && \
			tar zxf /tmp/buildroot.tar.gz -C /tmp && \
			mv /tmp/$(BUILDROOT_RELEASE) $(SRC_PATH); \
		else \
			git clone -b $(BUILDROOT_BRANCH) $(BUILDROOT_GIT); \
		fi; \
		# apply BR patches \
		cd $(SRC_PATH); \
		patch -p1 < .$(PATCH_PATH)/br-patch/0001-Add-libuwebsocket-package.patch; \
		patch -p1 < .$(PATCH_PATH)/br-patch/0002-Add-shairport-package.patch; \
	fi

audio:
	make -C $(AUDIO_PATH)

audioconfig: prepare
	make -C $(AUDIO_PATH) menuconfig

install: prepare audio
ifdef DRIVE
	echo -e "d\n\nd\n\nd\n\nd\no\n\nn\np\n1\n8192\n\n\nw\n" | sudo fdisk $(DRIVE)
	sudo dd if=$(AUDIO_PATH)/images/u-boot-sunxi-with-spl.bin of=${DRIVE} bs=1024 seek=8
	sudo mkfs.ext4 -F -L rootfs $(DRIVE)1
	sudo mount $(DRIVE)1 $(MOUNT_PATH)
	sudo tar -xf $(AUDIO_PATH)/images/rootfs.tar -C $(MOUNT_PATH)
	sudo umount $(MOUNT_PATH)
else
	$(info Define DRIVE variable (e.g. DRIVE=/dev/sdx))
endif

copy: prepare audio
ifdef TARGET
	if [ ! -d $(TARGET)/$(PROJECT_NAME) ]; then sudo mkdir $(TARGET)/$(PROJECT_NAME); fi
	sudo cp $(AUDIO_PATH)/images/u-boot.imx $(TARGET)/$(PROJECT_NAME)
	sudo cp $(AUDIO_PATH)/images/zImage $(TARGET)/$(PROJECT_NAME)
	sudo cp $(AUDIO_PATH)/images/*.dtb $(TARGET)/$(PROJECT_NAME)
	sudo cp $(AUDIO_PATH)/images/rootfs.ubi $(TARGET)/$(PROJECT_NAME)
else
	$(info Define TARGET variable (e.g. TARGET=/mnt/))
endif

clean: prepare
	make -C $(AUDIO_PATH) clean

mrproper: prepare
	make -C $(AUDIO_PATH) clean
	rm -rf $(SRC_PATH)

linuxconfig: prepare
	if [ -d $(KERNEL_PATH) ]; then \
		cp $(AUDIO_PATH)/kernel.cfg $(KERNEL_PATH)/.config; \
		make ARCH=arm -C $(KERNEL_PATH) menuconfig; \
		mv $(KERNEL_PATH)/.config $(AUDIO_PATH)/kernel.cfg; \
	else \
		echo "Kernel not found!"; \
	fi

help:
	# help           - this help
	# all            - default rule for build, triggers prepare and system"
	# prepare        - download necessary files - buildroot
	# audio          - default filesystem"
	# audioconfig    - start buildroot filesystem menuconfig"
	# linuxconfig    - start linux menuconfig"
	# copy           - copy created filesystems to TARGET folder
	# install        - copy system files and extract filesystem to DRIVE
	# clean          - clean all build files
	# mrproper       - clean all build files and remove all downloaded content
