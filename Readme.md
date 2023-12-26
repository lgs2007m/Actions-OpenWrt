# 借助 GitHub Actions 的 OpenWrt 在线自动编译.

#### hanwckf大佬mt798x闭源仓库- [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x).

#### 237大佬mt798x闭源仓库- [padavanonly/immortalwrt-mt798x](https://github.com/padavanonly/immortalwrt-mt798x).

#### hanwckf大佬的mt798x uboot仓库- [hanwckf/bl-mt798x](https://github.com/hanwckf/bl-mt798x).


## 脚本需要使用对应文件夹中的mtwifi-cfg.config配置文件，该配置文件是开启mtwifi-cf和编译luci-app-dockerman的。

## JDCloud-AX6000 workflow 手动运行可选项：
- [ ] Use the original MAC address order
- [ ] Use mtwifi-cfg
- [x] Build luci-app-dockerman

#### 1. Use the original MAC address order
该选项默认关闭，即不恢复WAN、LAN原厂顺序，需要开启请打钩。

目前源码的WAN、LAN的MAC地址读取位置与原厂相反，所以WAN、LAN与原厂MAC是反的。同时目前的WiFi MAC最后一个字节重启后会变。

开启该选项后可以恢复WAN、LAN原厂顺序，同时将WiFi MAC写到对应dat文件中，以便固定WiFi MAC。

#### 2. Use mtwifi-cfg
该选项默认关闭，即不使用mtwifi-cfg，使用luci-app-mtk，需要开启请打钩。

mtwifi-cfg：为mtwifi设计的无线配置工具，兼容openwrt原生luci和netifd，可调整无线驱动的参数较少，配置界面美观友好，由于是新开发的工具，可能存在一些问题。

luci-app-mtk：源自mtk-sdk提供的配置工具，需要配合wifi-profile脚本使用，可调整无线驱动的几乎所有参数，配置界面较为简陋。

区别详见大佬的博客[cmi.hanwckf.top](https://cmi.hanwckf.top/p/immortalwrt-mt798x/#mtwifi%E6%97%A0%E7%BA%BF%E9%85%8D%E7%BD%AE%E5%B7%A5%E5%85%B7%E8%AF%B4%E6%98%8E)

#### 3. Build luci-app-dockerman
该选项默认开启，即编译dockerman，需要关闭请取消打钩。

需要mtwifi-cfg.config配置文件中含luci-app-dockerman。


## CMCC-RAX3000M-EMMC workflow 手动运行可选项：
- [ ] Use the original MAC address order
- [ ] Use nx30pro eeprom
- [ ] Use mtwifi-cfg
- [x] Build luci-app-dockerman
- [ ] eMMC use 52MHz max-frequency

#### 1. Use the original MAC address order
该选项默认关闭，即不恢复WAN、LAN原厂顺序，需要开启请打钩。

目前源码的WAN、LAN的MAC地址读取位置与原厂相反，所以WAN、LAN与原厂MAC是反的。同时目前的WiFi MAC最后一个字节重启后会变。

开启该选项后可以恢复WAN、LAN原厂顺序，同时将WiFi MAC写到对应dat文件中，以便固定WiFi MAC。

#### 2. Use nx30pro eeprom
该选项默认关闭，即不使用nx30pro的高功率eeprom，需要开启请打钩。

RAX3000M的eeprom功率不高，可以通过替换高功率的eeprom提高信号强度。

开启该选项会使用nx30pro的eeprom替换掉MT7981_iPAiLNA_EEPROM.bin，并写入WiFi MAC到dat以便固定MAC。

#### 3. Use mtwifi-cfg
该选项默认关闭，即不使用mtwifi-cfg，使用luci-app-mtk，需要开启请打钩。

mtwifi-cfg：为mtwifi设计的无线配置工具，兼容openwrt原生luci和netifd，可调整无线驱动的参数较少，配置界面美观友好，由于是新开发的工具，可能存在一些问题。

luci-app-mtk：源自mtk-sdk提供的配置工具，需要配合wifi-profile脚本使用，可调整无线驱动的几乎所有参数，配置界面较为简陋。

区别详见大佬的博客[cmi.hanwckf.top](https://cmi.hanwckf.top/p/immortalwrt-mt798x/#mtwifi%E6%97%A0%E7%BA%BF%E9%85%8D%E7%BD%AE%E5%B7%A5%E5%85%B7%E8%AF%B4%E6%98%8E)

#### 4. Build luci-app-dockerman
该选项默认开启，即编译dockerman，需要关闭请取消打钩。

需要mtwifi-cfg.config配置文件中含luci-app-dockerman。


#### 5. eMMC use 52MHz max-frequency
该选项默认关闭，即不设置eMMC频率为52MHz，需要开启请打钩。

yml脚本中固定设置了eMMC使用highspeed，以便达到设置的26MHz、52MHz。

注意：除非更换过eMMC，不然不建议使用52MHz，基本跑一段时间都会出问题。老实使用26MHz即可。


### 感谢P3TERX的Actions-OpenWrt
- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
[Read the details in my blog (in Chinese) | 中文教程](https://p3terx.com/archives/build-openwrt-with-github-actions.html)
