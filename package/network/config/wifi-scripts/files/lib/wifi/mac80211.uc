#!/usr/bin/env ucode
import { readfile } from "fs";
import * as uci from 'uci';

const bands_order = [ "60G", "6G", "5G", "2G" ];
const htmode_order = [ "EHT", "HE", "VHT", "HT" ];

let board = json(readfile("/etc/board.json"));
if (!board.wlan)
	exit(0);

let idx = 0;
let commit;

let config = uci.cursor().get_all("wireless") ?? {};

function radio_exists(path, macaddr, phy, radio) {
	for (let name, s in config) {
		if (s[".type"] != "wifi-device")
			continue;
		if (radio != null && int(s.radio) != radio)
			continue;
		if (s.macaddr && lc(s.macaddr) == lc(macaddr))
			return true;
		if (s.phy == phy)
			return true;
		if (!s.path || !path)
			continue;
		if (substr(s.path, -length(path)) == path)
			return true;
	}
}

// 智慧自癒修剪：清理在 sysfs 中已不存在的幽靈 radio 與關聯 VAP (防範 PCIe 漂移與 radio3/4/5 堆疊)
for (let name, s in config) {
	if (s[".type"] != "wifi-device")
		continue;
	let is_ghost = false;
	if (s.path && !readfile("/sys/devices/platform/" + s.path + "/uevent"))
		is_ghost = true;
	else if (s.phy && !readfile("/sys/class/ieee80211/" + s.phy + "/macaddress"))
		is_ghost = true;

	if (is_ghost) {
		for (let ifc_name, ifc in config) {
			if (ifc[".type"] == "wifi-iface" && ifc.device == name) {
				print(`delete wireless.${ifc_name}\n`);
				delete config[ifc_name];
			}
		}
		print(`delete wireless.${name}\n`);
		delete config[name];
		commit = true;
	}
}

for (let phy_name, phy in board.wlan) {
	let info = phy.info;
	if (!info || !length(info.bands))
		continue;

	let radios = length(info.radios) > 0 ? info.radios : [{ bands: info.bands }];
	for (let radio in radios) {
		while (config[`radio${idx}`])
			idx++;
		let name = "radio" + idx;

		let s = "wireless." + name;
		let si = "wireless.default_" + name;

		let band_name = filter(bands_order, (b) => radio.bands[b])[0];
		if (!band_name)
			continue;

		let band = info.bands[band_name];
		let rband = radio.bands[band_name];
		let channel = rband.default_channel ?? "auto";

		let width = band.max_width;
		if (band_name == "2G")
			width = 20;
		else if (width > 80)
			width = 80;

		let htmode = filter(htmode_order, (m) => band[lc(m)])[0];
		if (htmode)
			htmode += width;
		else
			htmode = "NOHT";

		if (!phy.path)
			continue;

		let macaddr = trim(readfile(`/sys/class/ieee80211/${phy_name}/macaddress`));
		if (radio_exists(phy.path, macaddr, phy_name, radio.index))
			continue;

		let id = `phy='${phy_name}'`;
		if (match(phy_name, /^phy[0-9]/))
			id = `path='${phy.path}'`;

		band_name = lc(band_name);

		let country, encryption, defaults, num_global_macaddr;
		country = 'US';
		if (band_name == '6g') {
			encryption = 'owe';
		} else {
			encryption = 'none';
		}
		if (board.wlan.defaults) {
			defaults = board.wlan.defaults.ssids?.[band_name]?.ssid ? board.wlan.defaults.ssids?.[band_name] : board.wlan.defaults.ssids?.all;
			country = board.wlan.defaults.country || 'US';
			if (!country && band_name != '2g')
				defaults = null;
			num_global_macaddr = board.wlan.defaults.ssids?.[band_name]?.mac_count;
		}

		if (length(info.radios) > 0)
			id += `\nset ${s}.radio='${radio.index}'`;

		// Project X-Mesh SSoT 原則：出廠預設樣板 VAP 保持靜默 (disabled='1')，SSID 唯一定義自 Controller
		print(`set ${s}=wifi-device
set ${s}.type='mac80211'
set ${s}.${id}
set ${s}.band='${band_name}'
set ${s}.channel='${channel}'
set ${s}.htmode='${htmode}'
set ${s}.country='${country || "US"}'
set ${s}.num_global_macaddr='${num_global_macaddr || ''}'

set ${si}=wifi-iface
set ${si}.device='${name}'
set ${si}.network='lan'
set ${si}.mode='ap'
set ${si}.ssid='${defaults?.ssid || ""}'
set ${si}.encryption='${defaults?.encryption || encryption}'
set ${si}.key='${defaults?.key || ""}'
set ${si}.disabled='1'

`);
		config[name] = {};
		commit = true;
	}
}

if (commit)
	print("commit wireless\n");

