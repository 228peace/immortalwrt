define Device/askey_rt5010w-d156
	$(call Device/FitImage)
	$(call Device/UbiFit)
	DEVICE_VENDOR := Askey
	DEVICE_MODEL := RT5010W-D156
	DEVICE_DTS := ipq8072-askey-rt5010w-d156
	DEVICE_DTS_CONFIG := config@rev1
	DEVICE_DTS_DELIMITER := @
	SUPPORTED_DEVICES := askey,rt5010w-d156-rev1 askey,rt5010w-d156
	SOC := ipq8072
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	IMAGES := sysupgrade.tar
	IMAGE/sysupgrade.tar := sysupgrade-tar | append-metadata
	DEVICE_PACKAGES := kmod-usb3 kmod-usb-dwc3 kmod-usb-dwc3-qcom kmod-phy-aquantia
endef
TARGET_DEVICES += askey_rt5010w-d156
