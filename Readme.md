# 借助 GitHub Actions 的 OpenWrt 在线自动编译.

#### hanwckf大佬mt798x闭源仓库- [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x).

#### 237大佬mt798x闭源仓库- [padavanonly/immortalwrt-mt798x](https://github.com/padavanonly/immortalwrt-mt798x).

#### hanwckf大佬mt798x uboot仓库- [hanwckf/bl-mt798x](https://github.com/hanwckf/bl-mt798x).

### 刷砖也不怕！可以通过串口救砖：[MediaTek Filogic 系列路由器串口救砖教程](https://www.cnblogs.com/p123/p/18046679)
---
## JDCloud-AX6000-Baili workflow 手动运行可选项：
- Choose mt_wifi firmware
- Choose warp firmware
- [x] Use GSW switch driver (non-DSA)
- [ ] Use luci-app-mtk wifi config
- [ ] Not build luci-app-dockerman

- #### 说明
源码中的WAN、LAN地址顺序已修复并固定了WiFi MAC地址  

- #### 1. Choose mt_wifi/warp firmware
默认mt_wifi和warp使用TP XDR6088的fw-20230808，个人使用感觉无线ping丢包较少。  
mt_wifi：  
no-new-fw：不使用新的无线firmware，使用mt798x-7.6.6.1-src驱动中的fw-20220906  
mt7986-fw-20221208：使用mt7986-7.6.7.0-20221209-b9c02f-obj提取的fw-20221208  
mt7986-fw-jdc：使用JDCOS-JDC04-4.2.0.r4080固件提取的fw-20230228  
mt7986-fw-20230421：使用mtk-openwrt-feeds(20230421)的fw-20230421  
mt7986-fw-20230808：使用TP XDR6088的fw-20230808  
mt7986-fw-20231024：使用mtk-openwrt-feeds(20231024)的fw-20231024  
warp：  
no-new-fw：不使用新的无线firmware，使用warp_20221209-3e6ae1-src驱动中的fw-20221208，这个fw和mt7986-7.6.7.0-20221209-b9c02f-obj提取的fw-20221208相同  
mt7986-fw-jdc：使用JDCOS-JDC04-4.2.0.r4080固件提取的fw-20230308  
mt7986-fw-20230421：使用mtk-openwrt-feeds(20230421)的fw-20230421  
mt7986-fw-20230808：使用TP XDR6088的fw-20230808  
mt7986-fw-20231024：使用mtk-openwrt-feeds(20231024)的fw-20231024  

.mtwifi-cfg.config配置文件中已设置使用新的无线firmware：  
CONFIG_MTK_MT7986_NEW_FW=y  
CONFIG_WARP_NEW_FW=y  

- #### 2. Use GSW switch driver (non-DSA)
该选项默认开启，即使用GSW交换机驱动，需要按源码使用DSA交换机驱动的，请取消打钩。  
GSW：Gigabit Switch swconfig 模式，有交换机配置插件，不过京东云百里AX6000的WAN是单独接CPU的2.5G PHY RTL8221B，不接在MT7531交换机上，所以WAN不支持在交换机配置插件中设置VLAN。  
DSA：Distributed Switch Architecture 分布式交换架构模式，DSA去除了交换机配置插件，但在“网口”-“接口”-“设备”选项卡中的br-lan设备中的网桥VLAN过滤中可以查看网口状态设置VLAN。  
原厂固件和hanwckf大佬源码中京东云百里AX6000都是使用DSA的，hanwckf大佬、237大佬推荐使用GSW，使用GSW在切换WAN、LAN时硬件加速不失效。  
两者具体区别可以参考OpenWrt社区资料：[converting-to-dsa](https://openwrt.org/docs/guide-user/network/dsa/converting-to-dsa) [dsa-mini-tutorial](https://openwrt.org/docs/guide-user/network/dsa/dsa-mini-tutorial)  

- #### 3. Use luci-app-mtk wifi config
该选项默认关闭，即按.mtwifi-cfg.config配置文件，使用mtwifi-cfg配置工具，需要使用旧的luci-app-mtk无线配置工具请打钩。  
mtwifi-cfg：为mtwifi设计的无线配置工具，兼容openwrt原生luci和netifd，可调整无线驱动的参数较少，配置界面美观友好，由于是新开发的工具，可能存在一些问题。  
luci-app-mtk：源自mtk-sdk提供的配置工具，需要配合wifi-profile脚本使用，可调整无线驱动的几乎所有参数，配置界面较为简陋。  
区别详见大佬的博客[mtwifi无线配置工具说明](https://cmi.hanwckf.top/p/immortalwrt-mt798x/#mtwifi%E6%97%A0%E7%BA%BF%E9%85%8D%E7%BD%AE%E5%B7%A5%E5%85%B7%E8%AF%B4%E6%98%8E)  
.mtwifi-cfg.config配置文件中已设置使用mtwifi-cfg配置工具：  
CONFIG_PACKAGE_luci-app-mtwifi-cfg=y  
CONFIG_PACKAGE_luci-i18n-mtwifi-cfg-zh-cn=y  
CONFIG_PACKAGE_mtwifi-cfg=y  
CONFIG_PACKAGE_lua-cjson=y  

- #### 4. Not build luci-app-dockerman
该选项默认关闭，即按.mtwifi-cfg.config配置文件编译dockerman，不需要编译dockerman请打钩。  
.mtwifi-cfg.config配置文件中已设置编译dockerman：  
CONFIG_PACKAGE_luci-app-dockerman=y  

---
## CMCC-RAX3000M-eMMC/CMCC-XR30-eMMC workflow 手动运行可选项：
- [x] Use nx30pro eeprom and fixed WiFi MAC address
- [ ] Use luci-app-mtk wifi config
- [ ] Not build luci-app-dockerman

- #### 说明
源码中的WAN、LAN地址顺序已修复  
RAX3000M算力版（RAX3000M-eMMC）的eMMC默认使用26MHz频率  
RAX3000Z增强版（XR30-eMMC）的eMMC默认使用52MHz频率  

- #### 1. Use nx30pro eeprom and fixed WiFi MAC address
该选项默认开启，即使用nx30pro的高功率eeprom，不需要请取消打钩。  
不使用独立fem无线功放的MT7981B路由器可以通过替换高功率的eeprom提高信号强度。  
RAX3000M/XR30的factory eeprom设置功率不高，2.4G是23dBm、5G是22dBm，使用NX30 PRO的高功率eeprom，2.4G可提升至25dBm、5G提升至24dBm。  
开启该选项会使用NX30 PRO的eeprom替换掉固件中的MT7981_iPAiLNA_EEPROM.bin文件，并将facotry分区读取的MAC写入到dat以便固定WiFi MAC。  

- #### 2. Use luci-app-mtk wifi config
该选项默认关闭，即按.mtwifi-cfg.config配置文件，使用mtwifi-cfg配置工具，需要使用旧的luci-app-mtk无线配置工具请打钩。  
mtwifi-cfg：为mtwifi设计的无线配置工具，兼容openwrt原生luci和netifd，可调整无线驱动的参数较少，配置界面美观友好，由于是新开发的工具，可能存在一些问题。  
luci-app-mtk：源自mtk-sdk提供的配置工具，需要配合wifi-profile脚本使用，可调整无线驱动的几乎所有参数，配置界面较为简陋。  
区别详见大佬的博客[mtwifi无线配置工具说明](https://cmi.hanwckf.top/p/immortalwrt-mt798x/#mtwifi%E6%97%A0%E7%BA%BF%E9%85%8D%E7%BD%AE%E5%B7%A5%E5%85%B7%E8%AF%B4%E6%98%8E)  
.mtwifi-cfg.config配置文件中已设置使用mtwifi-cfg配置工具：  
CONFIG_PACKAGE_luci-app-mtwifi-cfg=y  
CONFIG_PACKAGE_luci-i18n-mtwifi-cfg-zh-cn=y  
CONFIG_PACKAGE_mtwifi-cfg=y  
CONFIG_PACKAGE_lua-cjson=y  

- #### 3. Not build luci-app-dockerman
该选项默认关闭，即按.mtwifi-cfg.config配置文件编译dockerman，不需要编译dockerman请打钩。  
.mtwifi-cfg.config配置文件中已设置编译dockerman：  
CONFIG_PACKAGE_luci-app-dockerman=y  

---
### 感谢P3TERX的Actions-OpenWrt
- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
[Read the details in my blog (in Chinese) | 中文教程](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

