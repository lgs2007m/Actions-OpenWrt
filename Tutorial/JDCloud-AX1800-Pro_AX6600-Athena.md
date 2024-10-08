最新教程和原厂固件下载链接：  
https://github.com/lgs2007m/Actions-OpenWrt/releases/tag/Router-Flashing-Files  

目录  
1.旧版本固件开SSH  
2.系统分区及eMMC简单介绍（不需要可以不看）  
3.备份分区（SSH备份 TTL备份）  
4.刷不死uboot和双分区gpt分区表  
5.新建storage分区并还原跑分分区  
6.USB 9008救砖  

下载好工具软件备用：  
SSH工具软件：Xshell https://pan.lanzoui.com/b0f19ry9g 或者putty https://www.423down.com/11333.html  
文件传输工具软件：WinSCP https://www.ghxi.com/winscp.html  
TFTP服务器工具：Tftpd64 https://bitbucket.org/phjounin/tftpd64/downloads/tftpd64.464.zip  


# 1.旧版本固件开SSH
1.5.40.r2181(2022-03-01)及之前版本SSH开门：  
直接浏览器登录路由器，浏览器上按F12打开控制台，在Console选项卡下方编辑区域粘贴并回车运行下方代码。  
然后就可以SSH登录路由器了，IP 192.168.68.1，端口22，用户名root，密码是路由器登录密码。  
注：如果Console不能输入代码，先解除浏览器上的限制。  
```
$.ajax({
    url: "/jdcapi",
    async: false,
    data: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "call",
        params: [
            $.cookie("sessionid"),
            "service",
            "set",
            {
                "name": "dropbear",
                "instances": {"instance1": {"command": ["/usr/sbin/dropbear"]}}
            }
        ]
    }),
    dataType: "json",
    type: "POST"
})
```

1.5.50r2204(2022-04-22)的SSH开门参考：  
京东云 - 郑羊羊咩的窝 https://zyyme.com/jdc.html  

1.5.80.r2262(2022-12-15)及之前版本SSH开门参考：  
京东云无线宝r2262之前固件版本开SSH（有限） https://www.bilibili.com/read/cv21409975  
京东云无线宝升级r2262固件后打开SSH（有限） https://www.bilibili.com/read/cv21907565  
注：因为固件联网会自动接收下发的热补丁干掉SSH进程，所以需要先断网，再重置系统才能开门。  
SSH开门后，只要联网也会下方补丁，SSH就没了。  
详见https://www.right.com.cn/forum/forum.php?mod=redirect&goto=findpost&ptid=8278061&pid=18501460  

1.5.80.r2262方法中在Linux或带USB的openwrt中生成uci.sh文件的快捷方式，将系统中的uci.sh映射到移动硬盘第二分区的uci.sh，以便通过添加网络位置编辑uci.sh，后面通过网络位置编辑uci.sh需要不报错正常保存才可以。  

1.5.81.r2279(2023-04-06)、4.0.0.r4015(2023-10-16)和最新4.3.0.r4211(2024-06-14)目前未见公开解锁SSH(Telnet)方法。  
【注意】在线升级4.3.0.r4211(2024-06-14)会强制更新uboot，官方新uboot不能中断，如果升级了只能USB 9008或者等公开解锁SSH(Telnet)方法。  
可以直接不死uboot刷4.3.0.r4211，uboot不会掉，但是不要官方系统上直接升级4.3.0.r4211。  

# 2.系统分区及eMMC简单介绍（不需要可以不看）
如果原厂系统可以开SSH，则SSH软件直接登录192.168.68.1，端口22，用户名root，密码是设置的路由器登录密码。  
不能开则只能拆机接USB转TTL（亚瑟建议1.8V电平的，雅典娜建议3.3V电平的），来备份和刷机了。  

下面以亚瑟为例，SSH登录输入blkid命令可以看到分区信息。  
亚瑟和雅典娜采用的分区布局相同，个别分区大小不同。  
注意使用TTL备份分区时，读分区是通过偏移量读取的，所以两者备份命令有所不同。  
SSH备份分区则是直接读取分区，两者备份分区命令相同。  

可以看到blkid输出中，许多分区都有两个，即一个正常命名的分区，一个尾部加“_1”的分区，其中系统分区有两组0:HLOS、rootfs、WIFIFW和0:HLOS_1、rootfs_1、WIFIFW_1，就是所说的双分区，共享同一个rootfs_data挂载系统数据。原厂分区表0:HLOS有6MB，rootfs只有60MB，所以原厂分区表下如果刷第三方单分区OP固件，只能小于60MB，且刷之后会利用剩余rootfs空间/dev/loop0挂载为overlay，可用空间更小。  
BOOTCONFIG和BOOTCONFIG1两个分区数据完全相同，存储分区切换的信息，除了上述的两组系统分区会在升级固件或者一些启动失败failsafe情况下切换，其他分区一般默认不变。但在官方进行强制更新时，其他分区会切换。比如BOOTCONFIG记录现在系统使用0:DEVCFG、0:DEVCFG、0:RPM、0:CDT、0:APPSBL这组分区启动，在官方进行强制更新single image镜像时就会刷写新的数据到另外一组带“_1”的分区，并更新BOOTCONFIG和BOOTCONFIG1，反之相同。其他分区是官方强制更新时才会切换，系统分区则是每次固件更新就切换，当然强制更新也会更新固件。如BOOTCONFIG记录使用的是0:HLOS、rootfs、WIFIFW，更新固件会写入数据到0:HLOS_1、rootfs_1、WIFIFW_1，并更新BOOTCONFIG和BOOTCONFIG1切换系统分区到0:HLOS_1、rootfs_1、WIFIFW_1。  

其他一些分区可以看下面的简单解释：  
GPT: GUID Partition Table (GPT分区表，在eMMC的UserData区域即/dev/mmcblk0的前34个扇区)  
SBL1: Secondary Boot Loader Stage 1  
BOOTCONFIG: Boot configuration (Failsafe partition information 存储分区切换的信息，其中第5个扇区存储age，即切换分区的次数，可以理解为原厂系统升级的次数)  
QSEE: Qualcomm Secure Execution Environment (TrustZone/TZ)  
DEVCFG: Device Configuration (Dynamic xPU configuration)  
RPM: Resource Power Manager  
CDT: Configuration Data Table (Platform ID and DDR configuration 包含平台ID和DDR参数，SBL1根据这个平台ID加载对应uboot，uboot根据平台ID加载对应DTB)  
ART: Atheros Radio Test (Wi-Fi calibration data 无线校准数据，包含MAC，每台机子是唯一的，注意备份)  
APPSBLENV: APPS Boot Loader Environment (U-Boot ENV variables U-Boot环境变量，建议备份)  
APPSBL: APPS Boot Loader (U-Boot applications boot loader)  
HLOS: High-Level Operating System (Kernel + DTB)  
rootfs: Root file system  
WIFIFW: Wi-Fi firmware  
rootfs_data: Root file system data (原厂固件需要挂载overlay到rootfs_data，一般单分区固件直接挂载overlay到/dev/loop0，不需要这个分区)  
plugin: 京东云原厂使用这个分区保存跑分log，不知为何命名为plugin分区  
log: 京东云原厂使用这个分区保存跑分插件，不知为何命名为log分区，恢复跑分并绑定，需要这个分区，建议备份  
swap: swap memory (这个分区是使用闪存空间当做虚拟内存，会损耗eMMC寿命)  
storage: 京东云原厂使用这个分区存储跑分的缓存数据  
BackupGPT: Backup GUID partition table (GPT备份分区表，在eMMC的UserData区域即/dev/mmcblk0的最后33个扇区)  

U-Boot (High-level boot loader for Linux)  
ELF (Executable and Linkable Format 可执行链接格式)  
MBN (Modem Configuration binary)  
XPU (Embedded Memory Protected Unit)  
DTB (Device Tree Blob 设备树二进制)  
DTS (Device Tree Source 设备树源码)  
FDT (Flattened Device Tree 扁平设备树)  

高通IPQ60XX、IPQ807X QSDK系统启动过程分析 https://www.openwrt.pro/post-595.html  
高通android开发摘要 https://www.cnblogs.com/liang123/p/6325271.html  
```
BusyBox v1.30.1 () built-in shell (ash)

 --------------------------------------------------------------------------
   Welcome to JDBox Router
 --------------------------------------------------------------------------

   $$$$$\ $$$$$$$\         $$$$$$\  $$\       $$$$$$\  $$\   $$\ $$$$$$$\  
   \__$$ |$$  __$$\       $$  __$$\ $$ |     $$  __$$\ $$ |  $$ |$$  __$$\ 
      $$ |$$ |  $$ |      $$ /  \__|$$ |     $$ /  $$ |$$ |  $$ |$$ |  $$ |
      $$ |$$ |  $$ |      $$ |      $$ |     $$ |  $$ |$$ |  $$ |$$ |  $$ |
$$\   $$ |$$ |  $$ |      $$ |      $$ |     $$ |  $$ |$$ |  $$ |$$ |  $$ |
$$ |  $$ |$$ |  $$ |      $$ |  $$\ $$ |     $$ |  $$ |$$ |  $$ |$$ |  $$ |
\$$$$$$  |$$$$$$$  |      \$$$$$$  |$$$$$$$$\ $$$$$$  |\$$$$$$  |$$$$$$$  |
 \______/ \_______/        \______/ \________|\______/  \______/ \_______/ 
                                                                     
 --------------------------------------------------------------------------
   For those about to rock... (1.5.40.r2181, facbb2f3e+r49254)
 --------------------------------------------------------------------------
root@JDBoxV2:~# blkid
/dev/mmcblk0: PTUUID="98101b32-bbe2-4bf2-a06e-2bb33d000c20" PTTYPE="gpt"
/dev/mmcblk0p1: PARTLABEL="0:SBL1" PARTUUID="76956397-a5ca-abcf-cfff-49da1c1c1be8"
/dev/mmcblk0p2: PARTLABEL="0:BOOTCONFIG" PARTUUID="7ba9c6de-ca09-2821-690a-64095242d2a0"
/dev/mmcblk0p3: PARTLABEL="0:BOOTCONFIG1" PARTUUID="1a1ed8db-f385-e8e6-9c74-e18d77bd489b"
/dev/mmcblk0p4: PARTLABEL="0:QSEE" PARTUUID="60f4eda8-3aad-0876-e16a-85254a9fd2a0"
/dev/mmcblk0p5: PARTLABEL="0:QSEE_1" PARTUUID="0cbb89b7-6322-4f98-2a36-c86b2161e82d"
/dev/mmcblk0p6: PARTLABEL="0:DEVCFG" PARTUUID="3871eeb7-ffd8-da0b-c61a-3b98b877a59e"
/dev/mmcblk0p7: PARTLABEL="0:DEVCFG_1" PARTUUID="4d84d3c2-4b7e-026a-3859-9399e060fd5b"
/dev/mmcblk0p8: PARTLABEL="0:RPM" PARTUUID="ad59f4d5-ef22-0f8f-08eb-e52be4d4fd62"
/dev/mmcblk0p9: PARTLABEL="0:RPM_1" PARTUUID="0315721b-068c-c728-8f13-b5154fe16902"
/dev/mmcblk0p10: PARTLABEL="0:CDT" PARTUUID="55d84ba7-7afe-068e-f02b-2b67dd330510"
/dev/mmcblk0p11: PARTLABEL="0:CDT_1" PARTUUID="8d32c906-b4e5-28bc-3050-5be0a3401b36"
/dev/mmcblk0p12: PARTLABEL="0:APPSBLENV" PARTUUID="a65238ed-379f-52e9-f01a-0e45a12d9da4"
/dev/mmcblk0p13: PARTLABEL="0:APPSBL" PARTUUID="88236518-8902-2ecf-6bfb-a33684f1fea0"
/dev/mmcblk0p14: PARTLABEL="0:APPSBL_1" PARTUUID="37a1760e-fea6-1e41-3446-9f4b78492b4c"
/dev/mmcblk0p15: PARTLABEL="0:ART" PARTUUID="e0ab46b9-b259-2644-58d6-5edd6f28e130"
/dev/mmcblk0p16: PARTLABEL="0:HLOS" PARTUUID="8a64c084-9d78-bc87-1438-cbeb2dd343ee"
/dev/mmcblk0p17: PARTLABEL="0:HLOS_1" PARTUUID="486078f8-baec-2466-2dc0-4e4d197f4440"
/dev/mmcblk0p18: TYPE="squashfs" PARTLABEL="rootfs" PARTUUID="39677e50-19f8-f4e2-71c0-8998c27e4b12"
/dev/mmcblk0p19: TYPE="squashfs" PARTLABEL="0:WIFIFW" PARTUUID="d1f6197d-bc9b-8f34-3d34-867f2a94c20a"
/dev/mmcblk0p20: TYPE="squashfs" PARTLABEL="rootfs_1" PARTUUID="8821dc34-da76-d18d-5141-7ed3c9c988d8"
/dev/mmcblk0p21: TYPE="squashfs" PARTLABEL="0:WIFIFW_1" PARTUUID="0665f737-3484-6a78-51fb-f5bc008dee0d"
/dev/mmcblk0p22: UUID="3d9a7891-66d6-4c9d-892f-10d850a7e19a" TYPE="ext4" PARTLABEL="rootfs_data" PARTUUID="a3c6191b-5e4b-9895-6289-886424d7a8ca"
/dev/mmcblk0p23: PARTLABEL="0:ETHPHYFW" PARTUUID="4a60b8d4-5f17-c1eb-5ea8-ada9a8fc0a9d"
/dev/mmcblk0p24: UUID="1d89ec7d-79d9-4a35-9329-30999a73f5af" TYPE="ext4" PARTLABEL="plugin" PARTUUID="4856f760-73f1-4db4-d89d-1eaae564bb24"
/dev/mmcblk0p25: UUID="1dc4f6fd-f03f-4589-9e37-409872cbde7c" TYPE="ext4" PARTLABEL="log" PARTUUID="380a410e-0479-abb6-37f7-0c792c436ef2"
/dev/mmcblk0p26: TYPE="swap" PARTLABEL="swap" PARTUUID="da210aab-3fdf-2640-f432-4c604371906b"
/dev/mmcblk0p27: UUID="afe9b133-ad0d-4f1f-86d6-c577b9df2490" TYPE="ext4" PARTLABEL="storage" PARTUUID="ceb8abfc-7258-fe04-17ae-6e699579e38f"
root@JDBoxV2:~# fdisk -l /dev/mmcblk0

Disk /dev/mmcblk0: 57.1 GiB, 61329113088 bytes, 119783424 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 98101B32-BBE2-4BF2-A06E-2BB33D000C20

Device                                            
/dev/mmcblk0p1                                    
/dev/mmcblk0p2                                    
/dev/mmcblk0p3                                    
/dev/mmcblk0p4                                    
/dev/mmcblk0p5                                    
/dev/mmcblk0p6                                    
/dev/mmcblk0p7                                    
/dev/mmcblk0p8                                    
/dev/mmcblk0p9                                    
/dev/mmcblk0p10                                   
/dev/mmcblk0p11                                   
/dev/mmcblk0p12                                   
/dev/mmcblk0p13                                   
/dev/mmcblk0p14                                   
/dev/mmcblk0p15                                   
/dev/mmcblk0p16                                   
/dev/mmcblk0p17                                   
/dev/mmcblk0p18                                   
/dev/mmcblk0p19                                   
/dev/mmcblk0p20                                   
/dev/mmcblk0p21                                   
/dev/mmcblk0p22                                   
/dev/mmcblk0p23                                   
/dev/mmcblk0p24                                   
/dev/mmcblk0p25                                   
/dev/mmcblk0p26                                   
/dev/mmcblk0p27                                   
root@JDBoxV2:~# cat /proc/partitions
major minor  #blocks  name

   1        0       4096 ram0
   1        1       4096 ram1
   1        2       4096 ram2
   1        3       4096 ram3
   1        4       4096 ram4
   1        5       4096 ram5
   1        6       4096 ram6
   1        7       4096 ram7
   1        8       4096 ram8
   1        9       4096 ram9
   1       10       4096 ram10
   1       11       4096 ram11
   1       12       4096 ram12
   1       13       4096 ram13
   1       14       4096 ram14
   1       15       4096 ram15
 179        0   59891712 mmcblk0
 179        1        768 mmcblk0p1
 179        2        256 mmcblk0p2
 179        3        256 mmcblk0p3
 179        4       1792 mmcblk0p4
 179        5       1792 mmcblk0p5
 179        6        256 mmcblk0p6
 179        7        256 mmcblk0p7
 179        8        256 mmcblk0p8
 179        9        256 mmcblk0p9
 179       10        256 mmcblk0p10
 179       11        256 mmcblk0p11
 179       12        256 mmcblk0p12
 179       13        640 mmcblk0p13
 179       14        640 mmcblk0p14
 179       15        256 mmcblk0p15
 179       16       6144 mmcblk0p16
 179       17       6144 mmcblk0p17
 179       18      61440 mmcblk0p18
 179       19       4096 mmcblk0p19
 179       20      61440 mmcblk0p20
 179       21       4096 mmcblk0p21
 179       22      20480 mmcblk0p22
 179       23        512 mmcblk0p23
 179       24      89600 mmcblk0p24
 179       25     307200 mmcblk0p25
 179       26     524288 mmcblk0p26
 179       27   58798046 mmcblk0p27
 179       32       4096 mmcblk0rpmb
root@JDBoxV2:~# cat /sys/kernel/debug/mmc0/ios
clock:    192000000 Hz
actual clock: 192000000 Hz
vdd:    18 (3.0 ~ 3.1 V)
bus mode: 2 (push-pull)
chip select:  0 (don't care)
power mode: 2 (on)
bus width:  3 (8 bits)
timing spec:  9 (mmc HS200)
signal voltage: 0 (1.80 V)
driver type:  0 (driver type B)
```
查看eMMC寿命（不知道准不准）：  
```
var="$(cat /sys/kernel/debug/mmc0/mmc0\:0001/ext_csd)"
eol=${var:534:2};slc=${var:536:2};mlc=${var:538:2}
echo "EOL:0x$eol SLC:0x$slc MLC:0x$mlc"
```
输出是这样的：  
```
root@JDBoxV2:~# var="$(cat /sys/kernel/debug/mmc0/mmc0\:0001/ext_csd)"
root@JDBoxV2:~# eol=${var:534:2};slc=${var:536:2};mlc=${var:538:2}
root@JDBoxV2:~# echo "EOL:0x$eol SLC:0x$slc MLC:0x$mlc"
EOL:0x01 SLC:0x04 MLC:0x01
```
EOL:0x01代表eMMC状态正常  
SLC:0x04代表已使用30%-40%的寿命，预计剩余60%。  
MLC:0x01江波龙这个型号的这个参数好像不变，不用看  
不同型号SLC和MCL定义不同，简单只看数最大的即可。  

或者刷第三方OP后自己安装mmc-utils再运行命令查看：  
```
opkg update
opkg install mmc-utils
mmc extcsd read /dev/mmcblk0 | grep -e "Life Time" -e "EOL"
```
查看emmc的启动设置命令：  
```
mmc extcsd read /dev/mmcblk0 | grep -e BOOT_BUS_CONDITIONS -e PARTITION_CONFIG -e RST_N_FUNCTION
```
可以看到亚瑟和雅典娜的eMMC并没有设置/dev/mmcblk0/boot0或者boot1硬件分区启动。  
SBL1在UserData硬件分区，这个硬件分区使用软件分区表GPT进行分区，SBL1在第一个软件分区上。  
```
root@QWRT:~# mmc extcsd read /dev/mmcblk0 | grep -e "Life Time" -e "EOL"
eMMC Life Time Estimation A [EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_A]: 0x04
eMMC Life Time Estimation B [EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_B]: 0x01
eMMC Pre EOL information [EXT_CSD_PRE_EOL_INFO]: 0x01
root@QWRT:~# mmc extcsd read /dev/mmcblk0 | grep -e BOOT_BUS_CONDITIONS -e PARTITION_CONFIG -e RST_N_FUNCTION
Boot configuration bytes [PARTITION_CONFIG: 0x00]
Boot bus Conditions [BOOT_BUS_CONDITIONS: 0x00]
H/W reset function [RST_N_FUNCTION]: 0x00
```

[EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_A]: life time estimation for the MLC user partition eraseblocks, provided in steps of 10%, e.g.:  
0x01 means 0%-10% device life time used.  
0x02 means 10%-20% device life time used.  
...  
[EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_B]: life time estimation for the SLC boot partition eraseblocks, provided in steps of 10%, e.g.:  
0x01 means 0%-10% device life time used.  
0x02 means 10%-20% device life time used.  
...   
[EXT_CSD_DEVICE_PRE_EOL_INFO]: overall status for reserved blocks. Possible values are:  
0x00 - Not defined.  
0x01 - Normal: consumed less than 80% of the reserved blocks.  
0x02 - Warning: consumed 80% of the reserved blocks.  
0x03 - Urgent: consumed 90% of the reserved blocks.  

寿命说明：0x0是未定义，0x1是已使用0-10%寿命，0x2是已使用10%-20%寿命，依次类推，详见下方  
https://wiki.friendlyelec.com/wiki/index.php/EMMC/zh  
eMMC 5.1 JEDEC标准  
https://pdfcoffee.com/jesd84-b51-pdf-free.html  


# 3.备份分区
## SSH备份分区
如果原厂系统可以开SSH，可以直接系统中备份分区。  
如果不能开则需要拆机TTL刷uboot，再刷旧版固件以便破解SSH。  
拆机接TTL详看TTL备份分区那部分的内容，先TTL备份uboot分区（0:APPSBL和0:APPSBL_1），当然原厂uboot不备份也可，然后TTL刷uboot。  
重启进uboot刷原厂1.5.40.r2181原厂固件，再按旧版本固件方法，不联网破解SSH后，系统中备份分区。  

刷其他第三方OP固件再备份也可，自行选择。  
第三方OP固件是单分区的，刷固件只是覆盖0:HLOS和rootfs这两个分区，不会影响其他分区数据。  
当然直接TTL（uboot控制台）备份也可，不过麻烦，详细TTL备份看后面。  

固件启动后SSH输入ls -l /mnt查看是是否挂载了/mnt/mmcblk0p27  
```
root@JDBoxV2:~# ls -l /mnt
drwxrwxrwx    4 root     root          4096 Mar 24 15:20 mmcblk0p27
```
刷其他OP没有挂载的，自己新建文件夹并挂载，然后再ls -l /mnt检查：  
```
mkdir /mnt/mmcblk0p27
mount -t ext4 /dev/mmcblk0p27 /mnt/mmcblk0p27
```
然后按照老方法备份到eMMC的storage分区即/mnt/mmcblk0p27，再通过WinScp登录路由器下载保存。  
WinScp软件登录原厂系统，协议SCP，IP 192.168.68.1，端口22。  
WInScp下载大文件会提示主机超过15秒无通信，需要登录时点击高级，高级站点设置-连接 去掉勾选“优化连接缓冲大小”，再登录。  

如果心疼读写2G数据到eMMC的话，备份到USB移动硬盘也可以，命令中/mnt/mmcblk0p27替换为USB的挂载点例如/mnt/sda1即可。  
确保USB移动硬盘有2G剩余空间，插上后查看移动硬盘的挂载点，这里是/mnt/sda1。  
```
root@JDBoxV2:~# ls -l /mnt
drwxrwxrwx    4 root     root          4096 Mar 24 15:20 mmcblk0p27
drwxrwxrwx    2 root     root          1024 Mar  1  2022 sda1
```
只备份GPT分区表和mmcblk0p1-26，mmcblk0p27是京东云跑分缓存数据，太大且恢复跑分可以重新缓存，不备份了。  
建议分开备份分区，后面需要的时候只要按顺序合并就得到了mmcblk0p0-26.img镜像了。  
复制下面全部命令粘贴执行，最后一行sync回车执行即可，注意看最后一个swap分区是否备份完成：  
```
dd if=/dev/mmcblk0 bs=512 count=34 of=/mnt/mmcblk0p27/mmcblk0_GPT.bin conv=fsync
dd if=/dev/mmcblk0p1 of=/mnt/mmcblk0p27/mmcblk0p1_0SBL1.bin conv=fsync
dd if=/dev/mmcblk0p2 of=/mnt/mmcblk0p27/mmcblk0p2_0BOOTCONFIG.bin conv=fsync
dd if=/dev/mmcblk0p3 of=/mnt/mmcblk0p27/mmcblk0p3_0BOOTCONFIG1.bin conv=fsync
dd if=/dev/mmcblk0p4 of=/mnt/mmcblk0p27/mmcblk0p4_0QSEE.bin conv=fsync
dd if=/dev/mmcblk0p5 of=/mnt/mmcblk0p27/mmcblk0p5_0QSEE_1.bin conv=fsync
dd if=/dev/mmcblk0p6 of=/mnt/mmcblk0p27/mmcblk0p6_0DEVCFG.bin conv=fsync
dd if=/dev/mmcblk0p7 of=/mnt/mmcblk0p27/mmcblk0p7_0DEVCFG_1.bin conv=fsync
dd if=/dev/mmcblk0p8 of=/mnt/mmcblk0p27/mmcblk0p8_0RPM.bin conv=fsync
dd if=/dev/mmcblk0p9 of=/mnt/mmcblk0p27/mmcblk0p9_0RPM_1.bin conv=fsync
dd if=/dev/mmcblk0p10 of=/mnt/mmcblk0p27/mmcblk0p10_0CDT.bin conv=fsync
dd if=/dev/mmcblk0p11 of=/mnt/mmcblk0p27/mmcblk0p11_0CDT_1.bin conv=fsync
dd if=/dev/mmcblk0p12 of=/mnt/mmcblk0p27/mmcblk0p12_0APPSBLENV.bin conv=fsync
dd if=/dev/mmcblk0p13 of=/mnt/mmcblk0p27/mmcblk0p13_0APPSBL.bin conv=fsync
dd if=/dev/mmcblk0p14 of=/mnt/mmcblk0p27/mmcblk0p14_0APPSBL_1.bin conv=fsync
dd if=/dev/mmcblk0p15 of=/mnt/mmcblk0p27/mmcblk0p15_0ART.bin conv=fsync
dd if=/dev/mmcblk0p16 of=/mnt/mmcblk0p27/mmcblk0p16_0HLOS.bin conv=fsync
dd if=/dev/mmcblk0p17 of=/mnt/mmcblk0p27/mmcblk0p17_0HLOS_1.bin conv=fsync
dd if=/dev/mmcblk0p18 of=/mnt/mmcblk0p27/mmcblk0p18_rootfs.bin conv=fsync
dd if=/dev/mmcblk0p19 of=/mnt/mmcblk0p27/mmcblk0p19_0WIFIFW.bin conv=fsync
dd if=/dev/mmcblk0p20 of=/mnt/mmcblk0p27/mmcblk0p20_rootfs_1.bin conv=fsync
dd if=/dev/mmcblk0p21 of=/mnt/mmcblk0p27/mmcblk0p21_0WIFIFW_1.bin conv=fsync
dd if=/dev/mmcblk0p22 of=/mnt/mmcblk0p27/mmcblk0p22_rootfs_data.bin conv=fsync
dd if=/dev/mmcblk0p23 of=/mnt/mmcblk0p27/mmcblk0p23_0ETHPHYFW.bin conv=fsync
dd if=/dev/mmcblk0p24 of=/mnt/mmcblk0p27/mmcblk0p24_plugin.bin conv=fsync
dd if=/dev/mmcblk0p25 of=/mnt/mmcblk0p27/mmcblk0p25_log.bin conv=fsync
dd if=/dev/mmcblk0p26 of=/mnt/mmcblk0p27/mmcblk0p26_swap.bin conv=fsync
sync
```
注意亚瑟和雅典娜GPT分区表是不一样的，因为有三个分区大小是不一样的：  
ART：    亚瑟256KiB    雅典娜512KiB  
plugin： 亚瑟87.5MiB   雅典娜87.25MiB  
log：    亚瑟300MiB    雅典娜1024 MiB  

## TTL备份分区
如果没有办法SSH或者eMMC已经接近挂了，路由器红灯重置也没有用，那只能拆机试试TTL有没有输出。  
【亚瑟拆机】
从机身底部开始拆，把底部橡胶垫对准5个角的部分撕开，就可以看到5颗十字螺丝，不需要把底部橡胶垫全部撕开。  
拆掉底盖5颗螺丝，拿下底盖，然后再拆支架的4颗十字螺丝，新机型顶部还有2颗十字螺丝，需要先垂直五边形用撬棒撬开顶盖，再拆这2颗螺丝。  
拆完之后可以把路由器横放在地上（地上用毛巾之类的垫着防止刮花）。  
有网口那一面横放，然后稍微用力往下压外壳，使之变形，以便网口陷进外壳，支架和主板可以从底部慢慢抽出来了。  
【亚瑟接TTL】
可以看到主板上4个并排的孔V R T G就是TTL接口了，VCC RX TX GND，线序详见刷机文件压缩包中的图片，亚瑟建议用1.8V的USB转TTL。  
VCC不用接，路由器的RX接USB转TTL的TX，路由器的TX接USB转TTL的RX，GND接GND。  
使用串口工具软件打开USB转TTL，然后路由器上电，串口工具软件会跑马，不停按回车中断启动进入uboot控制台。  
窗口出现 IPQ6018# 即进入uboot控制台了。  

【雅典娜拆机】
雅典娜需要轻轻撬开前面板，然后使用梅花带孔T10或者T9的螺丝刀扭开4颗螺丝就可以拆开外壳，还有内部有两颗螺丝需要3.5或3.0的十字螺丝刀。  
【雅典娜接TTL】
雅典娜支持TTL探针，只需要拆前面板，然后使用间距是2.54mm的TTL探针即可，详见刷机文件压缩包中的图片。  
有梅花带孔T10螺丝刀直接拆也可以，拆开可以看到主板边缘有TTL焊盘，需要焊接或者用夹子什么的固定住。雅典娜建议使用3.3V的USB转TTL，线序详见刷机文件压缩包中的图片。  
注：拆开散热器里面还有一组带孔的TTL接口。但是旧机子不改内存不建议拆散热器，拆开再装上不如之前的贴合度好，温度会提高1-2摄氏度。  

【搭建tftp服务器】
接好USB转TTL路由器上电开机，不停按回车中断启动进入uboot控制台。  
输入help命令可以查看uboot支持的命令，输入printenv查看环境变量。  
可以看到tftp服务器IP是192.168.10.1，电脑搭建fttp服务器，将电脑的有线网卡设置IP为192.168.10.1。  
关闭电脑防火墙，打开tftp软件Tftpd64，选择192.168.10.1网卡，则tftp服务器设置好了。  
网卡连接路由器LAN口，然后uboot控制台中输入ping 192.168.10.1来查看是否通。  
```
IPQ6018# printenv
baudrate=115200
bootargs=console=ttyMSM0,115200n8
bootcmd=bootipq
bootdelay=2
eth1addr=dc:d8:7c:00:00:4a
eth2addr=dc:d8:7d:00:00:4a
eth3addr=dc:d8:7e:00:00:4a
eth4addr=dc:d8:7c:00:00:4b
ethact=eth0
ethaddr=dc:d8:7b:00:00:4a
fdt_high=0x48500000
fdtcontroladdr=4a477ea0
flash_type=5
ipaddr=192.168.10.10       ##<<<<<<<<<<<<< 路由器IP
jdc_crc_enable=1
machid=8030201
netmask=255.255.255.0
serverip=192.168.10.1      ##<<<<<<<<<<<<< tftp服务器即电脑IP
soc_hw_version=20170100
soc_version_major=1
soc_version_minor=0
stderr=serial@78B1000
stdin=serial@78B1000
stdout=serial@78B1000

Environment size: 556/262140 bytes
```
TTL备份是通过mmc read先将分区读取到内存，再通过tftpput传给tftp服务器保存到电脑。  
不过tftpput命令好像传输过大，在传输完成后会重启，所以备份的单个分区不能太大。  
像最后两个分区log有300M（雅典娜log有1024M），swap有512M，我单独对这两个分区进行了分段备份。  
后面用BIN文件合并工具或者命令合并还原回log和swap分区。  
使用教程文件夹里的BIN文件合并工具V1.1合并，或者使用下面命令合并（自行修改文件名，注意文件顺序）。  
```
Linux：
cat file1.bin file2.bin file3.bin > merged_file.bin

Windows：
copy /B file1.bin + file2.bin + file3.bin merged_file.bin
```
mmc read命令用法：mmc read addr blk# cnt  
addr是数据读取到内存中的地址，blk#是要读取的扇区起始地址(十六进制)，一个扇区是512字节，cnt是要读取的扇区数量(十六进制)。  
tftpput用法：tftpput Address Size [[hostIPaddr:]filename]  
Address是要读取内存中数据的内存地址，Size是数据字节（十六进制）  
mmcblk0p27第27分区是京东云的数据分区，太大了不能备份，只能放弃了  

GPT分区表和前面14个分区大小，亚瑟和雅典娜是一样的，都用下面命令备份，复制命令一行一行执行即可：  
```
mmc read 0x50000000 0x00000000 0x00000022 && tftpput 0x50000000 0x00004400 mmcblk0p_GPT.bin
mmc read 0x50000000 0x00000022 0x00000600 && tftpput 0x50000000 0x000c0000 mmcblk0p1_0SBL1.bin
mmc read 0x50000000 0x00000622 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p2_0BOOTCONFIG.bin
mmc read 0x50000000 0x00000822 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p3_0BOOTCONFIG1.bin
mmc read 0x50000000 0x00000a22 0x00000e00 && tftpput 0x50000000 0x001c0000 mmcblk0p4_0QSEE.bin
mmc read 0x50000000 0x00001822 0x00000e00 && tftpput 0x50000000 0x001c0000 mmcblk0p5_0QSEE_1.bin
mmc read 0x50000000 0x00002622 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p6_0DEVCFG.bin
mmc read 0x50000000 0x00002822 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p7_0DEVCFG_1.bin
mmc read 0x50000000 0x00002a22 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p8_0RPM.bin
mmc read 0x50000000 0x00002c22 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p9_0RPM_1.bin
mmc read 0x50000000 0x00002e22 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p10_0CDT.bin
mmc read 0x50000000 0x00003022 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p11_0CDT_1.bin
mmc read 0x50000000 0x00003222 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p12_0APPSBLENV.bin
mmc read 0x50000000 0x00003422 0x00000500 && tftpput 0x50000000 0x000a0000 mmcblk0p13_0APPSBL.bin
mmc read 0x50000000 0x00003922 0x00000500 && tftpput 0x50000000 0x000a0000 mmcblk0p14_0APPSBL_1.bin
```
注意亚瑟和雅典娜GPT分区表是不一样的，因为有三个分区大小是不一样的：  
ART：    亚瑟256KiB    雅典娜512KiB  
plugin： 亚瑟87.5MiB   雅典娜87.25MiB  
log：    亚瑟300MiB    雅典娜1024 MiB  

【亚瑟】后面的分区备份命令，耐心复制命令一行一行执行：  
```
mmc read 0x50000000 0x00003e22 0x00000200 && tftpput 0x50000000 0x00040000 mmcblk0p15_0ART.bin
mmc read 0x50000000 0x00004022 0x00003000 && tftpput 0x50000000 0x00600000 mmcblk0p16_0HLOS.bin
mmc read 0x50000000 0x00007022 0x00003000 && tftpput 0x50000000 0x00600000 mmcblk0p17_0HLOS_1.bin
mmc read 0x50000000 0x0000a022 0x0001e000 && tftpput 0x50000000 0x03c00000 mmcblk0p18_rootfs.bin
mmc read 0x50000000 0x00028022 0x00002000 && tftpput 0x50000000 0x00400000 mmcblk0p19_0WIFIFW.bin
mmc read 0x50000000 0x0002a022 0x0001e000 && tftpput 0x50000000 0x03c00000 mmcblk0p20_rootfs_1.bin
mmc read 0x50000000 0x00048022 0x00002000 && tftpput 0x50000000 0x00400000 mmcblk0p21_0WIFIFW_1.bin
mmc read 0x50000000 0x0004a022 0x0000a000 && tftpput 0x50000000 0x01400000 mmcblk0p22_rootfs_data.bin
mmc read 0x50000000 0x00054022 0x00000400 && tftpput 0x50000000 0x00080000 mmcblk0p23_0ETHPHYFW.bin
mmc read 0x50000000 0x00054422 0x0002bc00 && tftpput 0x50000000 0x05780000 mmcblk0p24_plugin.bin

mmc read 0x50000000 0x00080022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log1.bin
mmc read 0x50000000 0x000a0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log2.bin
mmc read 0x50000000 0x000c0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log3.bin
mmc read 0x50000000 0x000e0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log4.bin
mmc read 0x50000000 0x00100022 0x00016000 && tftpput 0x50000000 0x02c00000 mmcblk0p25_log5.bin

mmc read 0x50000000 0x00116022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap1.bin
mmc read 0x50000000 0x00136022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap2.bin
mmc read 0x50000000 0x00156022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap3.bin
mmc read 0x50000000 0x00176022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap4.bin
mmc read 0x50000000 0x00196022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap5.bin
mmc read 0x50000000 0x001b6022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap6.bin
mmc read 0x50000000 0x001d6022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap7.bin
mmc read 0x50000000 0x001f6022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap8.bin
```

【雅典娜】后面的分区备份命令，耐心复制命令一行一行执行：  
```
mmc read 0x50000000 0x00003e22 0x00000400 && tftpput 0x50000000 0x00080000 mmcblk0p15_0ART.bin
mmc read 0x50000000 0x00004222 0x00003000 && tftpput 0x50000000 0x00600000 mmcblk0p16_0HLOS.bin
mmc read 0x50000000 0x00007222 0x00003000 && tftpput 0x50000000 0x00600000 mmcblk0p17_0HLOS_1.bin
mmc read 0x50000000 0x0000a222 0x0001e000 && tftpput 0x50000000 0x03c00000 mmcblk0p18_rootfs.bin
mmc read 0x50000000 0x00028222 0x00002000 && tftpput 0x50000000 0x00400000 mmcblk0p19_0WIFIFW.bin
mmc read 0x50000000 0x0002a222 0x0001e000 && tftpput 0x50000000 0x03c00000 mmcblk0p20_rootfs_1.bin
mmc read 0x50000000 0x00048222 0x00002000 && tftpput 0x50000000 0x00400000 mmcblk0p21_0WIFIFW_1.bin
mmc read 0x50000000 0x0004a222 0x0000a000 && tftpput 0x50000000 0x01400000 mmcblk0p22_rootfs_data.bin
mmc read 0x50000000 0x00054222 0x00000400 && tftpput 0x50000000 0x00080000 mmcblk0p23_0ETHPHYFW.bin
mmc read 0x50000000 0x00054622 0x0002ba00 && tftpput 0x50000000 0x05740000 mmcblk0p24_plugin.bin

mmc read 0x50000000 0x00080022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log1.bin
mmc read 0x50000000 0x000a0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log2.bin
mmc read 0x50000000 0x000c0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log3.bin
mmc read 0x50000000 0x000e0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log4.bin
mmc read 0x50000000 0x00100022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log5.bin
mmc read 0x50000000 0x00120022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log6.bin
mmc read 0x50000000 0x00140022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log7.bin
mmc read 0x50000000 0x00160022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log8.bin
mmc read 0x50000000 0x00180022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log9.bin
mmc read 0x50000000 0x001a0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log10.bin
mmc read 0x50000000 0x001c0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log11.bin
mmc read 0x50000000 0x001e0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log12.bin
mmc read 0x50000000 0x00200022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log13.bin
mmc read 0x50000000 0x00220022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log14.bin
mmc read 0x50000000 0x00240022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log15.bin
mmc read 0x50000000 0x00260022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p25_log16.bin

mmc read 0x50000000 0x00280022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap1.bin
mmc read 0x50000000 0x002a0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap2.bin
mmc read 0x50000000 0x002c0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap3.bin
mmc read 0x50000000 0x002e0022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap4.bin
mmc read 0x50000000 0x00300022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap5.bin
mmc read 0x50000000 0x00320022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap6.bin
mmc read 0x50000000 0x00340022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap7.bin
mmc read 0x50000000 0x00360022 0x00020000 && tftpput 0x50000000 0x04000000 mmcblk0p26_swap8.bin
```

# 4.刷uboot和双分区gpt分区表
注意：用谁的uboot看谁的教程，我的uboot是亚瑟雅典娜通刷，别人的我不知道，不要乱用！！！  
我这个uboot是可以亚瑟、雅典娜通用的，不区分双分区、单分区，默认uboot刷固件都会刷到0:HLOS、rootfs。  
如果擦除了0:BOOTCONFIG和0:BOOTCONFIG1分区，则启动只会用到第一个命名正常的分区（即不是尾部有“_1”的分区），uboot只会启动系统分区0:HLOS、rootfs。  
如果保留0:BOOTCONFIG和0:BOOTCONFIG1分区，则按分区里面的设置启动对应的系统分区。  
为了更好支持原厂系统，我是保留0:BOOTCONFIG和0:BOOTCONFIG1支持双分区的，gpt分区表也使用的是双分区扩容分区表。  

## SSH刷写
已开SSH的可以SSH刷写，没有看下方的拆机TTL方法。  
WinScp上传uboot文件uboot-JDC_AX1800_Pro-AX6600_Athena-20240510.bin到tmp文件夹，然后SSH输入命令刷写uboot到0:APPSBL和0:APPSBL_1分区：  
```
dd if=/tmp/uboot-JDC_AX1800_Pro-AX6600_Athena-20240510.bin of=$(blkid -t PARTLABEL=0:APPSBL -o device) conv=fsync
dd if=/tmp/uboot-JDC_AX1800_Pro-AX6600_Athena-20240510.bin of=$(blkid -t PARTLABEL=0:APPSBL_1 -o device) conv=fsync
```
输入命令检查分区md5 hash值，和我这版2024.05.10编译的md5一致即可：  
```
md5sum $(blkid -t PARTLABEL=0:APPSBL -o device) && md5sum $(blkid -t PARTLABEL=0:APPSBL_1 -o device)
```
```
root@JDBoxV2:~# md5sum $(blkid -t PARTLABEL=0:APPSBL -o device) && md5sum $(blkid -t PARTLABEL=0:APPSBL_1 -o device)
5e1817f795ada48335fda9f22545a43e  /dev/mmcblk0p13
5e1817f795ada48335fda9f22545a43e  /dev/mmcblk0p14
```
分区表文件夹中的gpt文件，rootfs512M对应rootfs是512MB大小，依次类推。  
这个rootfs就是固件+overlay的大小，overlay近似是刷固件后剩余软件包空间大小，选择自己需要的rootfs大小的分区表即可。  
因为刷分区表是改变了后面的分区的偏移量，所以后面分区的数据就不能识别了。  
后面会讲到，如果要回原厂跑分，需要先恢复log、plugin、swap，后面新建的最后一个storage分区也要格式化才能用。  

注意亚瑟和雅典娜的gpt分区表不同，不要上传错了！！！  
上传你需要的rootfs大小的gpt分区表文件到tmp文件夹，先验证md5：  
```
md5sum /tmp/gpt-JDC_*_dual-boot_rootfs*M_no-last-partition.bin
```
```
root@JDBoxV2:~# md5sum /tmp/gpt-JDC_*_dual-boot_rootfs*M_no-last-partition.bin
##亚瑟gpt md5
9d9e3803ba541ff38449acd181026b28  /tmp/gpt-JDC_AX1800_Pro_dual-boot_rootfs512M_no-last-partition.bin
5aaf1b606458fbffc72342540db9bc52  /tmp/gpt-JDC_AX1800_Pro_dual-boot_rootfs1024M_no-last-partition.bin
b93b4823af2b4fc31d22c25468181e7a  /tmp/gpt-JDC_AX1800_Pro_dual-boot_rootfs2048M_no-last-partition.bin
##雅典娜gpt md5
3447887a5f47893fa099c7c076eeeee3  /tmp/gpt-JDC_AX6600_Athena_dual-boot_rootfs512M_no-last-partition.bin
1f8217d1f0e0478d2e884278ea30ece5  /tmp/gpt-JDC_AX6600_Athena_dual-boot_rootfs1024M_no-last-partition.bin
9a921ca450e8a5aebd218b7fd1d1c5a8  /tmp/gpt-JDC_AX6600_Athena_dual-boot_rootfs2048M_no-last-partition.bin
```
自己硬改eMMC并且使用我的分区表需要注意：  
雅典娜rootfs 2048M分区表总扇区数已大于4G，建议使用8G及以上eMMC。其他亚瑟雅典娜的分区表总扇区数是小于4G的，理论可以使用4G及以上大小eMMC。  

原厂eMMC的不需要关注上面这个注意信息。  
你上传的文件的md5信息和上面对应文件的md5对比，没问题即可。  
接着修改下面命令中的gpt文件名为你上传的文件名，然后复制命令粘贴一起执行：  
（只修改gpt文件名，其他不变，这里以rootfs512M的分区表为例）  
第1条dd命令是写入gpt文件到/dev/mmcblk0的前34个扇区  
第2条是dd读取分区表传递给md5sum校验数据的md5值  
```
## 亚瑟 rootfs size 512M GPT
dd if=/tmp/gpt-JDC_AX1800_Pro_dual-boot_rootfs512M_no-last-partition.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
dd if=/dev/mmcblk0 bs=512 count=34 | md5sum
```
```
## 雅典娜 rootfs size 512M GPT
dd if=/tmp/gpt-JDC_AX6600_Athena_dual-boot_rootfs512M_no-last-partition.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
dd if=/dev/mmcblk0 bs=512 count=34 | md5sum
```
查看输出的md5，和上传文件的md5一样即可断电进uboot刷factory.bin固件了。  
刷第三方OP固件后再进行新建分区、还原分区操作。  
## TTL刷写
没有开SSH的，只能用TTL刷写uboot，然后uboot刷原厂1.5.40.r2181固件，不联网破解SSH后备份分区，再刷分区表。  
电脑设置ip 192.168.10.1/24，关闭防火墙，把uboot文件放在tftp服务软件根目录，打开tftp服务软件。  
USB转TTL，亚瑟建议使用1.8V的TTL电平，雅典娜建议使用3.3V的，连接路由器串口，电脑使用串口软件打开串口。  
串口TTL接线可以教程文件夹中的图片。  
路由器上电后不停按回车，中断启动，然后输入命令刷写：  
```
tftpboot uboot-JDC_AX1800_Pro-AX6600_Athena-20240510.bin && flash 0:APPSBL && flash 0:APPSBL_1
```
可以输入命令检查分区crc32 hash值：  
```
mmc read 0x50000000 0x00003422 0x500 && crc32 0x50000000 0xA0000
mmc read 0x51000000 0x00003922 0x500 && crc32 0x51000000 0xA0000
```
输出是这样的，最后得到我改的2024.05.10编译的uboot crc32值是3ab2f8a6：  
```
IPQ6018# mmc read 0x50000000 0x00003422 0x500 && crc32 0x50000000 0xA0000

MMC read: dev # 0, block # 13346, count 1280 ... 1280 blocks read: OK
crc32 for 50000000 ... 5009ffff ==> 3ab2f8a6
IPQ6018# mmc read 0x51000000 0x00003922 0x500 && crc32 0x51000000 0xA0000

MMC read: dev # 0, block # 14626, count 1280 ... 1280 blocks read: OK
crc32 for 51000000 ... 5109ffff ==> 3ab2f8a6
```

如果你已经备份好分区了，也可以直接TTL刷分区表。  
把你需要的rootfs大小的gpt分区表放在tftp的根目录下，然后用下面命令刷写。  
这里以rootfs 512M为例，其他的自行修改命令中的文件名。  
```
## 亚瑟刷gpt
tftpboot gpt-JDC_AX1800_Pro_dual-boot_rootfs512M_no-last-partition.bin && mmc write $fileaddr 0x0 0x22
```
```
## 雅典娜刷gpt
tftpboot gpt-JDC_AX6600_Athena_dual-boot_rootfs512M_no-last-partition.bin && mmc write $fileaddr 0x0 0x22
```
刷完之后可以验证crc32：  
```
mmc read 0x50000000 0x0 0x22 && && crc32 0x50000000 0x4400
```
对应crc32值如下：  
```
## 亚瑟gpt crc32值
B1CC2783  gpt-JDC_AX1800_Pro_dual-boot_rootfs512M_no-last-partition.bin
1D500B9C  gpt-JDC_AX1800_Pro_dual-boot_rootfs1024M_no-last-partition.bin
BE66A69F  gpt-JDC_AX1800_Pro_dual-boot_rootfs2048M_no-last-partition.bin
## 雅典娜gpt crc32值
98B76783  gpt-JDC_AX6600_Athena_dual-boot_rootfs512M_no-last-partition.bin
3A3064A4  gpt-JDC_AX6600_Athena_dual-boot_rootfs1024M_no-last-partition.bin
8D513E9D  gpt-JDC_AX6600_Athena_dual-boot_rootfs2048M_no-last-partition.bin
```
和文件的crc32一样即可断电进uboot刷factory.bin固件了。  
刷第三方OP固件后再进行新建分区、还原分区操作。  

## uboot支持固件说明
uboot始终刷写固件到系统0并设置BOOTCONFIG后从系统0启动，即从0:HLOS、rootfs启动。  
20240510版uboot开始，刷固件会清除固件的配置数据，不管刷OP还是原厂固件。  
如果直接擦除0:BOOTCONFIG、0:BOOTCONFIG1分区，则始终从系统0启动。  
注意，我的20240510版uboot开始在刷原厂固件的时候会擦除rootfs_data分区，即不保留原厂固件的设置信息。  

uboot支持原厂固件，需要分区表有0:HLOS、rootfs、0:WIFIFW和rootfs_data这几个分区。这个0:HLOS就是kernel。  
原厂是双分区gpt分区表，包含0:HLOS、rootfs、0:WIFIFW和另一组0:HLOS_1、rootfs_1、0:WIFIFW_1，共享一个rootfs_data。  
目前OP系统不使用0:WIFIFW、rootfs_data分区，而是将固件的kernel刷入0:HLOS，固件rootfs刷入rootfs分区，剩余rootfs分区的空间/dev/loop0挂载为overlay使用。  
为了有更大空间刷OP，可以在原厂双分区gpt基础上修改出扩大rootfs大小（其他分区不变，storage大小需要根据调整改变）的双分区分区表使用，  
也可以删除0:HLOS_1、rootfs_1分区，再扩大rootfs大小（其他分区不变，storage大小需要根据调整改变）变为单分区分区表使用。  
单分区分区表则擦除0:BOOTCONFIG、0:BOOTCONFIG1分区，使系统始终从系统0启动。  
无论是单还是双分区，原厂固件需要使用rootfs_data、0:WIFIFW分区，不然不能启动，所以要使用原厂固件需要有rootfs_data、0:WIFIFW分区。  
单分区或者双分区分区表都可以在原厂系统中更新原厂固件。  
如果需要跑分，刷了其他分区表，该分区表除了rootfs_data、0:WIFIFW分区还需要有0:ETHPHYFW、plugin、log、swap这些分区，  
并将备份的分区数据恢复到这几个分区，同时OP下格式化最后一个storage分区，然后uboot刷回原厂固件。
系统启动后打开无线宝app，存储设置内置存储为本地网盘，然后直接恢复出厂，启动后再进入app设置内置存储为智能加速服务。  

uboot支持kernel固定6M大小的OP factory.bin固件，如大雕的QWRT factory.bin固件。  
OP仅需要分区表有0:HLOS、rootfs即可。  

## uboot使用
电脑网线接路由器lan口，电脑ip设置192.168.1.2/24，然后路由器上电，按住reset按键不放，LED灯红色会闪烁5次，然后LED灯会变蓝色。  
LED变蓝色说明uboot failsafe webui已经开启，浏览器打开登录地址192.168.1.1。建议关闭所有网页，重新打开浏览器去打开192.168.1.1，避免出错。  
上传文件点击更新后，LED灯蓝色闪烁，此时后台在上传文件并更新，更新完后出现UPDATE IN PROGRESS页面，同时LED灯会变绿3秒，没亮绿灯的是不成功，刷新浏览器192.168.1.1重新上传并更新。  
【注意】个别机友反映刷uboot后设置固定ip进不来uboot的webui。这个可能是网卡和uboot的驱动不兼容，此时可尝试将网卡速率的自动协商手动修改为10M全双工，再尝试访问webui。刷好固件后再修改回自动协商。  


uboot页面下方version:2024.05.10_12:22:07是编译时间。  
uboot更新gpt后，建议进系统SSH登录再输入命令保存下分区表：  
```
echo -e 'w' | fdisk /dev/mmcblk0
```
其实保存分区表更建议用sgdisk或gdisk，不过一般固件没有集成需要自行安装：  
```
sgdisk -e /dev/mmcblk0
```
进入uboot webui更新固件：支持kernel为6MB大小的factory.bin和官方原厂固件JDCOS-JDC02。  
http://192.168.1.1  
更新ART：  
http://192.168.1.1/art.html  
更新CDT：上传CDT文件需要大于10KB  
http://192.168.1.1/cdt.html  
更新IMG：可更新GPT分区表或者EMMC IMG镜像  
http://192.168.1.1/img.html  
更新U-BOOT：  
http://192.168.1.1/uboot.html  
注意：上传文件点击更新后，蓝灯会闪烁，然后更新成功后绿灯会亮3秒，没有亮绿灯的不成功，刷新浏览器192.168.1.1重新上传并更新。建议关闭所有网页，重新打开浏览器去打开192.168.1.1，避免出错。  


# 5.新建storage分区并还原跑分分区
我刷分区表和新建分区使用到sgdisk，但原厂系统安装插件报错。  
所以刷好uboot后直接uboot刷第三方OP factory.bin固件，固件启动后，先手动安装sgdisk，当然在线安装也可。  

上传sgdisk文件夹中的ipk到/tmp文件夹，然后用下面命令安装：  
```
opkg install /tmp/sgdisk_1.0.6-1_aarch64_cortex-a53.ipk
```
接着使用下面命令，新建storage分区（亚瑟、雅典娜使用同一个命令即可）：  
```
sgdisk -e -n 0:0:0 -c 0:storage -t 0:1B1720DA-A8BB-4B6F-92D2-0A93AB9609CA -p /dev/mmcblk0
```
会输出如下信息，以亚瑟64G为例：
```
root@QWRT:~# sgdisk -e -n 0:0:0 -c 0:storage -t 0:1B1720DA-A8BB-4B6F-92D2-0A93AB9609CA -p /dev/mmcblk0
Warning: Partition table header claims that the size of partition table
entries is 0 bytes, but this program  supports only 128-byte entries.
Adjusting accordingly, but partition table may be garbage.
Caution: invalid backup GPT header, but valid main header; regenerating
backup header from main header.

Warning! Main and backup partition tables differ! Use the 'c' and 'e' options
on the recovery & transformation menu to examine the two tables.

Warning! One or more CRCs don't match. You should repair the disk!
Main header: OK
Backup header: ERROR
Main partition table: OK
Backup partition table: ERROR

****************************************************************************
Caution: Found protective or hybrid MBR and corrupt GPT. Using GPT, but disk
verification and recovery are STRONGLY recommended.
****************************************************************************
Setting name!
partNum is 26
Disk /dev/mmcblk0: 119783424 sectors, 57.1 GiB
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): 98101B32-BBE2-4BF2-A06E-2BB33D000C20
Partition table holds up to 28 entries
Main partition table begins at sector 2 and ends at sector 8
First usable sector is 34, last usable sector is 119783390
Partitions will be aligned on 2-sector boundaries
Total free space is 0 sectors (0 bytes)

Number  Start (sector)    End (sector)  Size       Code  Name
   1              34            1569   768.0 KiB   A012  0:SBL1
   2            1570            2081   256.0 KiB   FFFF  0:BOOTCONFIG
   3            2082            2593   256.0 KiB   FFFF  0:BOOTCONFIG1
   4            2594            6177   1.8 MiB     A016  0:QSEE
   5            6178            9761   1.8 MiB     FFFF  0:QSEE_1
   6            9762           10273   256.0 KiB   FFFF  0:DEVCFG
   7           10274           10785   256.0 KiB   FFFF  0:DEVCFG_1
   8           10786           11297   256.0 KiB   A018  0:RPM
   9           11298           11809   256.0 KiB   FFFF  0:RPM_1
  10           11810           12321   256.0 KiB   A01B  0:CDT
  11           12322           12833   256.0 KiB   FFFF  0:CDT_1
  12           12834           13345   256.0 KiB   FFFF  0:APPSBLENV
  13           13346           14625   640.0 KiB   A015  0:APPSBL
  14           14626           15905   640.0 KiB   FFFF  0:APPSBL_1
  15           15906           16417   256.0 KiB   FFFF  0:ART
  16           16418           28705   6.0 MiB     FFFF  0:HLOS
  17           28706           40993   6.0 MiB     FFFF  0:HLOS_1
  18           40994         1089569   512.0 MiB   FFFF  rootfs
  19         1089570         1097761   4.0 MiB     FFFF  0:WIFIFW
  20         1097762         1220641   60.0 MiB    FFFF  rootfs_1
  21         1220642         1228833   4.0 MiB     FFFF  0:WIFIFW_1
  22         1228834         1269793   20.0 MiB    FFFF  rootfs_data
  23         1269794         1270817   512.0 KiB   FFFF  0:ETHPHYFW
  24         1270818         1450017   87.5 MiB    FFFF  plugin
  25         1450018         2064417   300.0 MiB   FFFF  log
  26         2064418         3112993   512.0 MiB   FFFF  swap
  27         3112994       119783390   55.6 GiB    FFFF  storage
Warning: The kernel is still using the old partition table.
The new table will be used at the next reboot or after you
run partprobe(8) or kpartx(8)
The operation has completed successfully.
```
注意亚瑟和雅典娜GPT分区表是不一样的，因为有三个分区大小是不一样的：  
ART：    亚瑟256KiB    雅典娜512KiB  
plugin： 亚瑟87.5MiB   雅典娜87.25MiB  
log：    亚瑟300MiB    雅典娜1024 MiB  

没有报错，sgdisk最后输出successfully即可，有错误则及时排错。新建错了重刷分区表，接着重新新建分区。  
检查第18分区rootfs是分区表设置的大小，比如rootfs512M的分区表rootfs就是512MB。  
检查第27分区storage大小接近整个EMMC大小，比如64G EMMC，storage分区有55GB左右。  

建议此时备份下载修改后的分区表，以后有问题进不了系统，可以直接uboot刷这个分区表。  
当然刷no-last-partition的分区表后再新建分区也行，一样的。  
```
dd if=/dev/mmcblk0 bs=512 count=34 of=/tmp/mmcblk0_GPT_sgdisk.bin
```
都没有问题可以SSH输入reboot重启了。  
固件启动后再格式化最后一个分区并恢复京东云跑分的分区。  
如果不需要跑分了，系统启动后格式化下最后一个分区，修复下swap分区，再重启下就行。  
```
mkfs.ext4 $(blkid -t PARTLABEL=storage -o device)
```
```
swapoff $(blkid -t PARTLABEL=swap -o device)
mkswap $(blkid -t PARTLABEL=swap -o device)
swapon $(blkid -t PARTLABEL=swap -o device)
```
swapoff命令如果swap分区已经卸载，会报错，这是正常的，不用管：failed to swapoff /dev/mmcblk0p26 (-1)  

如果需要跑分，则不用在这里修复swap分区，可以直接往下看，恢复plugin、log、swap分区。  
因为保留了双分区，所以刷uboot和gpt之后还是支持原厂系统的。  
原厂系统升级会覆盖另外一个系统分区，如此反复。第三方OP一般是单分区固件，只在第一个系统分区升级，不会覆盖第二个系统分区。  

回官方原厂直接uboot刷回即可，但是要跑分需要恢复跑分的分区。  
刷回原厂后想要再刷第三方OP则直接uboot刷即可，不需要其他操作了，可以自由切换。  

可以将要恢复的分区文件拷贝到USB设备然后刷回，我这里以上传到/mnt/mmcblk0p27挂载点为例。  
前面已经格式化了storage分区，这里直接新建文件夹并挂载即可。  
```
mkdir /mnt/mmcblk0p27
mount -t ext4 /dev/mmcblk0p27 /mnt/mmcblk0p27
```
WinSCP之类软件上传下面3个备份文件到/mnt/mmcblk0p27  
mmcblk0p24_log.bin  
mmcblk0p25_plugin.bin  
mmcblk0p26_swap.bin  

使用下面命令刷回：  
```
dd if=/dev/zero of=$(blkid -t PARTLABEL=0:ETHPHYFW -o device) conv=fsync
dd if=/mnt/mmcblk0p27/mmcblk0p24_plugin.bin of=$(blkid -t PARTLABEL=plugin -o device) conv=fsync
dd if=/mnt/mmcblk0p27/mmcblk0p25_log.bin of=$(blkid -t PARTLABEL=log -o device) conv=fsync
swapoff $(blkid -t PARTLABEL=swap -o device)
dd if=/mnt/mmcblk0p27/mmcblk0p26_swap.bin of=$(blkid -t PARTLABEL=swap -o device) conv=fsync
swapon $(blkid -t PARTLABEL=swap -o device)
```
第1个命令如果swap分区已经卸载，会报错，这是正常的，不用管：failed to swapoff /dev/mmcblk0p26 (-1)  
第2个命令dd像mmcblk0p23没有空间，这是正常的，不用管：error writing '/dev/mmcblk0p23': No space left on device  
其他几个个命令没有报错即可。  

恢复完分区后可以删除文件，重启下就行。  

如果后面要回原厂跑分，进入uboot直接刷原厂固件。  
系统启动后打开无线宝app，存储设置内置存储为本地网盘，然后直接恢复出厂，启动后再进入app设置内置存储为智能加速服务。  
恢复智能跑分服务后可能无线宝app中的服务状态一直在自动修复，灯是蓝色的不能马上变绿灯，需要等待，我试的情况是有可能需要1-2个小时才恢复绿灯。  
如果刷回原厂超过2小时跑分服务一直在修复，可以尝试重新刷log、plugin、swap分区。  
再重试设置内置存储为本地网盘，然后直接恢复出厂，启动后再设置内置存储为智能加速服务。  
如何恢复分区回原厂快速开始跑分，我没有摸索出规律，所以得大家自己多尝试。  


##【刷分区表的一点小提示】##  
建议用fdisk、gdisk之类的进行修改分区。  
如果不慎修改后系统不能启动，可以进入uboot，浏览器输入 http://192.168.1.1/img.html 重新刷正常的gpt分区表即可。  

如果uboot或系统中更换了其他分区表，但不需要使用前面的sgdisk命令新建分区并保存分区表。  
这样则建议在系统中使用fdisk或者sgdisk（一般需要先安装）单独保存下分区表：  
例如系统中单独写gpt分区表：  
```
dd if=/tmp/gpt.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
```
则建议保存下分区表：  
```
echo -e 'w' | fdisk /dev/mmcblk0
```
或者
```
sgdisk -e /dev/mmcblk0
```
##【关于分区表不包含最后那个大分区的原因】##  
gpt分区表的最大扇区数不能大于EMMC的物理最大扇区数，小于等于则没问题。比如128G的EMMC刷64G的分区表可以，刷256G的分区表会出错。  
MT798X EMMC机子的bl2在boot0硬件分区，不受userdata硬件分区的gpt分区表影响，即使gpt坏了也可以启动uboot，所以比较抗揍。  
比如百里测试刷最大扇区数大于EMMC扇区数的分区表也能启动uboot，只是固件启动会报错，可以进uboot重新刷正常的分区表。  
不过高通IPQ60XX EMMC机子SBL是在userdata硬件分区中由gpt分区表划分出来的第一个软件分区，会受到gpt分区表的影响。  
比如京东云AX1800 Pro亚瑟测试直接刷最大扇区数大于EMMC扇区数的分区表会砖，需要USB救砖。  

同时如果最后一个大的分区超过了EMMC的扇区数，fdisk、parted、gdisk这些工具并不能直接修复，仍然需要删除新建。  

基于这两个原因，我改的分区表都采用天灵大佬的gpt分区表的做法，不保留最后一个最大的分区了，即no-last-partition。  
这样的分区表只包含前面的小分区，扇区总数是小于4G，所以适用所有大于4G的EMMC。  
注意：因为雅典娜rootfs 2048M已经超过4G，所以如果自行更换eMMC使用雅典娜rootfs 2048M分区表的，建议使用8G及以上的eMMC。  
刷好no-last-partition分区表后，使用sgdisk用未分配空间新建一个分区，并还原分区的type code。  


# 6.USB 9008救砖
USB救砖不是万能，只有特定情况可以不拆机。  
可以不拆机的情况：  
只要变砖后使用双公头USB-A线（有Tpye-C接口的也可以用一头Tpye-C一头USB-A数据线）接路由器和电脑，电脑设备管理器显示QUSB或Qualcomm HS-USB QDLoader 9008的，就可以直接救砖。会导致变砖路由器直接进入高通9008模式的情况：  
1.刷坏gpt分区表，导致不能启动SBL1，只擦除gpt的话会使用EMMC最后33个扇区保存的备份gpt启动，不会砖；  
2.擦除或者刷其他文件（非ipq60xx系列SBL1）到SBL1分区，QSEE、DEVCFG、RPM这个分区同理，不过这个几个没什么刷的；  
3.擦除uboot分区（即0:APPSBL分区）或者刷了其他文件（非ipq60xx系列uboot）到该分区；  
4.擦除cdt分区（即0:CDT分区）或者刷了非cdt文件到该分区。  
需要拆机短接电阻进入高通9008模式的情况：  
1.刷错了ipq60xx系列uboot（如ax5_jdc gl-ax1800 uboot）到uboot分区，这种情况会启动SBL1加载uboot，导致不能直接进9008，要拆机用镊子短接启动电阻焊盘，才可以进9008;  
2.刷错了cdt（如ax5_jdc gl-ax1800 cdt）到cdt分区。  

详见USB救砖教程压缩包。  

