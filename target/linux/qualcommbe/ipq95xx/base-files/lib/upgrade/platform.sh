#!/bin/sh
# shellcheck disable=SC2034
PART_NAME=firmware
REQUIRE_IMAGE_METADATA=1

RAMFS_COPY_BIN='fw_printenv fw_setenv head'
RAMFS_COPY_DATA='/etc/fw_env.config /var/lock/fw_printenv.lock'

platform_check_image() {
	case "$(board_name)" in
	askey,sbe1v1k)
		if ! grep -q "PARTNAME=kernel" /sys/block/mmcblk0/mmcblk0p*/uevent 2>/dev/null; then
			local kern_size
			kern_size=$(tar -tvf "$1" 2>/dev/null | grep -E '/kernel$' | awk '{print $3}' || echo 0)
			if [ -n "$kern_size" ] && [ "$kern_size" -gt 7340032 ] 2>/dev/null; then
				echo "Error: Kernel size (${kern_size} bytes) exceeds 7MB 0:HLOS partition on OEM layout!"
				return 1
			fi
		fi
		return 0
		;;
	*)
		return 0
		;;
	esac
}

platform_do_upgrade() {
	case "$(board_name)" in
	8devices,kiwi-dvk)
		CI_KERNPART="0:HLOS"
		CI_ROOTPART="rootfs"
		emmc_do_upgrade "$1"
		;;
	askey,sbe1v1k)
		if grep -q "PARTNAME=kernel" /sys/block/mmcblk0/mmcblk0p*/uevent 2>/dev/null; then
			CI_KERNPART="kernel"
			CI_ROOTPART="rootfs"
			CI_DATAPART="rootfs_data"
		else
			CI_KERNPART="0:HLOS"
			CI_ROOTPART="rootfs"
		fi
		emmc_do_upgrade "$1"
		;;
	*)
		default_do_upgrade "$1"
		;;
	esac
}

platform_copy_config() {
	case "$(board_name)" in
	8devices,kiwi-dvk|\
	askey,sbe1v1k)
		emmc_copy_config
		;;
	esac
}
