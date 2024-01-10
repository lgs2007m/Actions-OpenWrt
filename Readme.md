# 借助 GitHub Actions 的 OpenWrt 在线自动编译.

#### hanwckf大佬mt798x闭源仓库- [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x).

#### 237大佬mt798x闭源仓库- [padavanonly/immortalwrt-mt798x](https://github.com/padavanonly/immortalwrt-mt798x).

#### hanwckf大佬mt798x uboot仓库- [hanwckf/bl-mt798x](https://github.com/hanwckf/bl-mt798x).


### 脚本需要使用对应文件夹中的mtwifi-cfg.config配置文件，该配置文件开启mtwifi-cfg并含luci-app-dockerman，以供可选项修改。
---
## JDCloud-AX6000 workflow 手动运行可选项：
- [ ] Use the original MAC address order
- [ ] Use GSW switch driver (non-DSA)
- [ ] Use mtwifi-cfg
- [x] Build luci-app-dockerman

- #### 1. Use the original MAC address order
该选项默认关闭，即不恢复WAN、LAN原厂顺序，需要开启请打钩。  
目前源码的WAN、LAN的MAC地址读取位置与原厂相反，所以WAN、LAN与原厂MAC是反的。同时目前的WiFi MAC最后一个字节重启后会变。  
开启该选项后可以恢复WAN、LAN原厂顺序，同时将WiFi MAC写到对应dat文件中，以便固定WiFi MAC。

- #### 2. Use GSW switch driver (non-DSA)
该选项默认关闭，即不适用GSW交换机驱动，使用DSA交换机驱动，需要开启请打钩。  
GSW：Gigabit Switch swconfig 模式，有交换机配置插件，不过JDCloud-AX6000的WAN不接在交换机上，所以WAN不支持在交换机配置插件中设置VLAN。  
DSA：Distributed Switch Architecture 分布式交换架构模式，DSA去除了交换机配置插件，但在“网口”-“接口”-“设备”选项卡中的br-lan设备中的网桥VLAN过滤中可以查看网口状态设置VLAN。  
原厂固件和hanwckf大佬源码中JDCloud-AX6000都是使用DSA的，建议使用DSA。两者区别可以参考OpenWrt社区资料。  

OpenWrt社区资料：  
https://openwrt.org/docs/guide-user/network/dsa/converting-to-dsa  
https://openwrt.org/docs/guide-user/network/dsa/dsa-mini-tutorial  

- #### 3. Use mtwifi-cfg
该选项默认关闭，即不使用mtwifi-cfg，使用luci-app-mtk，需要开启请打钩。  
mtwifi-cfg：为mtwifi设计的无线配置工具，兼容openwrt原生luci和netifd，可调整无线驱动的参数较少，配置界面美观友好，由于是新开发的工具，可能存在一些问题。  
luci-app-mtk：源自mtk-sdk提供的配置工具，需要配合wifi-profile脚本使用，可调整无线驱动的几乎所有参数，配置界面较为简陋。  
区别详见大佬的博客[cmi.hanwckf.top](https://cmi.hanwckf.top/p/immortalwrt-mt798x/#mtwifi%E6%97%A0%E7%BA%BF%E9%85%8D%E7%BD%AE%E5%B7%A5%E5%85%B7%E8%AF%B4%E6%98%8E)

- #### 4. Build luci-app-dockerman
该选项默认开启，即编译dockerman，需要关闭请取消打钩。  
需要mtwifi-cfg.config配置文件中含luci-app-dockerman。

---
## CMCC-RAX3000M-EMMC workflow 手动运行可选项：
- [ ] Use the original MAC address order
- [ ] Use nx30pro eeprom
- [ ] Use mtwifi-cfg
- [x] Build luci-app-dockerman
- [ ] eMMC use 52MHz max-frequency

- #### 1. Use the original MAC address order
该选项默认关闭，即不恢复WAN、LAN原厂顺序，需要开启请打钩。  
目前源码的WAN、LAN的MAC地址读取位置与原厂相反，所以WAN、LAN与原厂MAC是反的。同时目前的WiFi MAC最后一个字节重启后会变。  
开启该选项后可以恢复WAN、LAN原厂顺序，同时将WiFi MAC写到对应dat文件中，以便固定WiFi MAC。

- #### 2. Use nx30pro eeprom
该选项默认关闭，即不使用nx30pro的高功率eeprom，需要开启请打钩。  
RAX3000M的eeprom功率不高，可以通过替换高功率的eeprom提高信号强度。  
开启该选项会使用nx30pro的eeprom替换掉MT7981_iPAiLNA_EEPROM.bin，并写入WiFi MAC到dat以便固定MAC。

- #### 3. Use mtwifi-cfg
该选项默认关闭，即不使用mtwifi-cfg，使用luci-app-mtk，需要开启请打钩。  
mtwifi-cfg：为mtwifi设计的无线配置工具，兼容openwrt原生luci和netifd，可调整无线驱动的参数较少，配置界面美观友好，由于是新开发的工具，可能存在一些问题。  
luci-app-mtk：源自mtk-sdk提供的配置工具，需要配合wifi-profile脚本使用，可调整无线驱动的几乎所有参数，配置界面较为简陋。  
区别详见大佬的博客[cmi.hanwckf.top](https://cmi.hanwckf.top/p/immortalwrt-mt798x/#mtwifi%E6%97%A0%E7%BA%BF%E9%85%8D%E7%BD%AE%E5%B7%A5%E5%85%B7%E8%AF%B4%E6%98%8E)

- #### 4. Build luci-app-dockerman
该选项默认开启，即编译dockerman，需要关闭请取消打钩。  
需要mtwifi-cfg.config配置文件中含luci-app-dockerman。


- #### 5. eMMC use 52MHz max-frequency
该选项默认关闭，即不设置eMMC频率为52MHz，需要开启请打钩。  
原厂机子选用的eMMC颗粒品质不太行，不能运行在MT7981B eMMC最高的52MHz频率，所以原厂固件使用的是26MHz频率。  
yml脚本中固定设置了eMMC使用highspeed，以便达到设置的26MHz、52MHz。  
注意：除非更换过eMMC，不然不建议使用52MHz，基本跑一段时间都会出问题。老实使用26MHz即可。

---
### 感谢P3TERX的Actions-OpenWrt
- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
[Read the details in my blog (in Chinese) | 中文教程](https://p3terx.com/archives/build-openwrt-with-github-actions.html)
