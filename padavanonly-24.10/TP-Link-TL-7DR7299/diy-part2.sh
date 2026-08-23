#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After ./scripts/feeds update -a, Before ./scripts/feeds install -a)
#

rm -rf feeds/packages/net/open-app-filter
git clone https://github.com/destan19/OpenAppFilter package/luci-app-oaf
##-----Update golang for luci-app-openlist2------
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
git clone https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist2
git clone https://github.com/EasyTier/luci-app-easytier package/luci-app-easytier
git clone https://github.com/gdy666/luci-app-lucky package/luci-app-lucky
git clone https://github.com/LazuliKao/luci-theme-fluent package/luci-theme-fluent
git clone https://github.com/eamonxg/luci-theme-shadcn package/luci-theme-shadcn
rm -rf feeds/luci/themes/luci-theme-argon
git clone https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
##-----Fix nginx.config for luci-app-quickfile------
cat > feeds/packages/net/nginx-util/files/nginx.config << 'EOF'

config main global
	option uci_enable 'true'

config server '_lan'
	option server_name '_lan'
	list listen '80 default_server'
	list listen '[::]:80 default_server'
	list include 'conf.d/*.locations'
	option access_log 'off; # logd openwrt'
EOF
git clone https://github.com/sbwml/luci-app-quickfile package/luci-app-quickfile
# Modify default IP
#sed -i 's/192.168.6.1/192.168.1.1/g' package/base-files/files/bin/config_generate

##-----------------Add OpenClash meta core------------------
curl -sL -m 30 --retry 2 https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz -o /tmp/clash.tar.gz
tar zxvf /tmp/clash.tar.gz -C /tmp >/dev/null 2>&1
chmod +x /tmp/clash >/dev/null 2>&1
mkdir -p feeds/luci/applications/luci-app-openclash/root/etc/openclash/core
mv /tmp/clash feeds/luci/applications/luci-app-openclash/root/etc/openclash/core/clash_meta >/dev/null 2>&1
rm -rf /tmp/clash.tar.gz >/dev/null 2>&1
##-----------------Delete DDNS's examples-----------------
sed -i '/myddns_ipv4/,$d' feeds/packages/net/ddns-scripts/files/etc/config/ddns
##-----------------Display fixed frequency info for MT7988A-----------------
sed -i '/"mediatek"\/\*|"mvebu"\/\*)/i "mediatek/filogic_a73")\n\tcpu_freq="1.8GHz" ;;' package/emortal/autocore/files/generic/cpuinfo
##-----------------Remove password------------------
sed -i 's/^root:.*$/root:::0:99999:7:::/' package/base-files/files/etc/shadow

##-----------------Fix 10G Ethernet LED configuration------------------
sed -i '
  /led@3/,/};/ {
    s/function = LED_FUNCTION_LAN;/function = LED_FUNCTION_WAN;/
  }
' target/linux/mediatek/dts/mt7988a-tplink-tl-7dr7299-v1.dts
##-----------------Set status LED default-on------------------
sed -i '
  /tplink,tl-7dr7299-v1)/,/;;/ {
    /ucidef_set_led_netdev "wan" "WAN" "green:status" "wan" "link tx rx"/d
    /ucidef_set_led_netdev "10g-eth" "10G Ethernet" "mdio-bus:01:green:10ge" "eth1"/a\
\tucidef_set_led_default "status" "STATUS" "green:status" "1"\
\t_ucidef_set_led_trigger "status" "STATUS" "green:status" "default-on"
  }
' target/linux/mediatek/filogic_a73/base-files/etc/board.d/01_leds
