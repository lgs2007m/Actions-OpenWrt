最新教程下载链接：  
https://github.com/lgs2007m/Actions-OpenWrt/releases/tag/Router-Flashing-Files  

目录  
0.开SSH  
1.备份原厂分区  
2.刷uboot  
3.刷gpt分区表  
4.uboot刷固件、格式化data分区和切换固件  
5.刷回原厂  
6.串口TTL救砖  

mt798x的fip分区实际上包含bl31+uboot，为了方便理解，这里的教程将fip直接称为uboot。  

本教程使用基于hanwckf大佬bl-mt798x仓库uboot-202206源码修改编译的bl2、uboot和gpt，不支持DHCP。  
目前已同时支持21.02闭源固件(.bin格式Legacy image)和openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)直接刷入启动，可在SSH修改环境变量，直接切换启动两种固件，无需重刷，配置保留。  

uboot及gpt源码请查看 https://github.com/lgs2007m/bl-mt798x/tree/emmc  
感谢天灵等一众大佬提供的FIT image支持，感谢hanwckf大佬的bl-mt798x项目。  

- ### 版本识别
CMCC RAX3000M配置是MT7981B+DDR4 512M+MT7976CN+MT7531，有两个版本，区别只在闪存，普通版：128M SPI-NAND闪存，算力版：64G eMMC闪存。  
NAND普通版：盒子背部和机子背部标签是“CH”字样，生产日期20230515、20230606、20231027、20231124基本就是，或者透过散热孔看PCB右上角印丝结尾是P3。  
eMMC算力版：盒子背部和机子背部标签是“CH EC”字样，生产日期20230626、20230703、20231226基本都是，或者透过散热孔看PCB右上角印丝结尾是P1。  

新出的CMCC XR30和RAX3000M配置相同，也分区两个版本，eMMC版包装盒正面印的信息是RAX3000Z增强版，机子正面有全屋组网的标志，背面和顶上有贴纸，底部标签有算力版标识。NAND普通版盒子正面印的是CMCC XR30，机子正面没有全屋组网的标志，背面，顶上都没有贴纸，底部的标签也大一圈，标签上没有算力版的标识。虽然它俩具体型号相同，但是增强版才是eMMC的，CMCC XR30目前看是NAND的。  
RAX3000M算力版有三个LED灯，RAX3000Z增强版只有两个。它们的刷机文件互刷也没有问题，只不过LED可能不对。  

如果不确定NAND还是eMMC版本，建议解锁SSH后用命令查看分区，看哪个命令输出分区就是哪个版本：  
```
# NAND
cat /proc/mtd
```
```
# EMMC
fdisk -l /dev/mmcblk0
```

- ### 准备刷机文件和工具软件
最新刷机文件下载：https://github.com/lgs2007m/Actions-OpenWrt/releases/tag/Router-Flashing-Files  
SSH工具软件：Xshell https://pan.lanzoui.com/b0f19ry9g  或者putty https://www.423down.com/11333.html  
文件传输工具软件：WinSCP https://www.ghxi.com/winscp.html  

关于mt798x改内存：目前开源ATF 7981 DDR3最高512M，DDR4最高1G；7986 DDR3最高512M，DDR4 2G。  

- ### 0.开SSH
导出配置文件，因为文件没有加密，所以直接修改里面的dropbear和rc.local增加打开SSH的命令，修改shadow文件清除root密码即可。  
RAX3000M和XR30的配置文件通用，可以直接用刷机文件压缩包里面的配置文件，导入恢复配置，等待机子重启应用，即可开启SSH。  
Xshell或者putty之类的软件登录SSH，地址192.168.10.1，端口22，用户名root，密码无。  

解锁SSH的配置文件有两个，其中RAX3000M_XR30_cfg-ssh.conf是不加密的，RAX3000M_XR30_cfg-ssh-salted-20231027.conf是加密的，主要用于生产日期20231027及之后的RAX3000M NAND普通版。  
RAX3000M算力版旧版使用的是不加密的配置文件RAX3000M_XR30_cfg-ssh.conf，不过新版20231124开始的算力版也加密了，如果不行就使用加密的配置文件RAX3000M_XR30_cfg-ssh-salted-20231027.conf。  
目前XR30使用不加密的配置文件RAX3000M_XR30_cfg-ssh.conf。  

查看配置文件是否加密，使用[WinHex](https://www.ghxi.com/winhex.html)之类的二进制软件，查看文件开头有Salted__字符串，就是openssl的加盐加密。  
或者直接当压缩文件用7z打开，能打开的是不加密的，打不开的一般是加密的，需要到固件代码中找加密命令和密码。  

【原厂新版固件配置文件加解密】  
20240115/20240117等批次、最新批次的部分机子是新固件，已经更换了配置文件加密密码，经过[lyq1996](https://github.com/lyq1996)大佬逆向，发现新密码是根据SN生成的，所以每台机子不一样。感谢 @lyq1996 大佬！  

新版原厂固件已经删除了dropbear，所以我做了一个开启telnet的配置备份文件RAX3000M_XR30_cfg-telnet-20240117.conf，这个配置文件是没有加密的，需要使用命令根据机子的SN加密得到最终的配置文件，再上传导入配置，等待重启后即可解锁telnet。  

使用openwrt、ubuntu、WSL等linux系统，对我做的配置文件RAX3000M_XR30_cfg-telnet-20240117.conf进行加密，得到解锁telnet的配置文件cfg_import_config_file_new.conf。Windows系统也可以安装Cygwin来运行。  
将我做的配置文件放到linux系统中，在文件所在目录打开终端（或者打开终端，使用cd命令打开文件所在路径），然后修改SN为你机子的，再运行命令：  
```
SN=081116000043333
mypassword=$(openssl passwd -1 -salt aV6dW8bD "$SN")
mypassword=$(eval "echo $mypassword")
echo $mypassword
openssl aes-256-cbc -pbkdf2 -k "$mypassword" -in RAX3000M_XR30_cfg-telnet-20240117.conf -out cfg_import_config_file_new.conf
```
命令没有报错即可，就得到新版加密配置文件了。  

如果想自己修改配置文件，可以用下面命令解密配置文件（需先生成密码）：
```
openssl aes-256-cbc -d -pbkdf2 -k "$mypassword" -in cfg_export_config_file.conf -out cfg_import_config_file_decrypt.conf
```

Windows系统也可以安装Cygwin来运行上面的命令：  
64位在线安装程序：https://www.cygwin.com/setup-x86_64.exe  
32位在线安装程序：https://www.cygwin.com/setup-x86.exe  
直接运行一路下一步，安装好之后运行Cygwin，输入df命令查看挂载路径。比如E盘对应的是/cygdrive/e，输入命令`cd /cygdrive/e`打开E盘路径。  
将我做的配置文件放到E盘根目录，然后修改SN再用上面的命令加密配置文件。  

如果所有方法都不行，那终极大招是通过TTL使用mtk_uartboot直接加载uboot到内存，直接刷uboot。 

RAX3000M eMMC算力版和RAX3000Z增强版的分区是一样的，所以gpt分区表和备份分区通用。  
下面简单看下原厂分区的信息，不想了解的可以略过。  
可以看到原厂有两个系统分区kernel、rootfs和kernel2、rootfs2，即双分区，共用一个256MB的rootfs_data。kernel、kernel2都是32MB，rootfs、rootfs2都只有64MB。  
固件中kernel一般占3MB左右，分区表kernel分区32MB完全够用，但是rootfs大小限制了原厂双分区分区表刷固件的大小。  
因此原厂双分区分区表下刷固件不能大于kernel+rootfs大小即67MB。  
输入df -h可以看到overlay直接挂载到了/dev/mmcblk0p8即rootfs_data分区，而不是挂载overlay到/dev/loop0。
df -h可以看到/dev/mmcblk0p10、11都挂载到了/mnt/mmcblk0p11，原厂就是这样，不影响所以不用管。  
```
root@RAX3000M:~# fdisk -l /dev/mmcblk0
Found valid GPT with protective MBR; using GPT

Disk /dev/mmcblk0: 120832000 sectors, 1656M
Logical sector size: 512
Disk identifier (GUID): 2bd17853-102b-4500-aa1a-8a21d4d7984d
Partition table holds up to 128 entries
First usable sector is 34, last usable sector is 120800000

Number  Start (sector)    End (sector)  Size Name
     1            8192            9215  512K u-boot-env
     2            9216           13311 2048K factory
     3           13312           17407 2048K fip
     4           17408           82943 32.0M kernel
     5           82944          214015 64.0M rootfs
     6          214016          279551 32.0M kernel2
     7          279552          410623 64.0M rootfs2
     8          410624          934911  256M rootfs_data
     9          934912         1065983 64.0M plugins
    10         1065984         1098751 16.0M fwk
    11         1098752         1131519 16.0M fwk2
    12         1131520       120800000 57.0G data
root@RAX3000M:~# df -h
Filesystem                Size      Used Available Use% Mounted on
/dev/root                14.0M     14.0M         0 100% /rom
tmpfs                   240.6M     17.5M    223.2M   7% /tmp
/dev/mmcblk0p8          254.0M     85.5M    168.5M  34% /overlay
overlayfs:/overlay      254.0M     85.5M    168.5M  34% /
tmpfs                   512.0K         0    512.0K   0% /dev
/dev/mmcblk0p10           7.6M      7.6M         0 100% /mnt/mmcblk0p11
/dev/mmcblk0p11           7.6M      7.6M         0 100% /mnt/mmcblk0p11
/dev/mmcblk0p12          55.9G     52.0M     53.0G   0% /mnt/mmcblk0p12
/dev/mmcblk0p9           58.0M      1.3M     52.2M   2% /mnt/mmcblk0p9
/dev/mmcblk0p12          55.9G     52.0M     53.0G   0% /extend
/dev/mmcblk0p9           58.0M      1.3M     52.2M   2% /plugin
/dev/loop0                7.6M      7.6M         0 100% /plugin/cmcc/framework
root@RAX3000M:~# blkid
/dev/loop0: TYPE="squashfs"
/dev/mmcblk0p1: PARTLABEL="u-boot-env" PARTUUID="19a4763a-6b19-4a4b-a0c4-8cc34f4c2ab9"
/dev/mmcblk0p2: PARTLABEL="factory" PARTUUID="8142c1b2-1697-41d9-b1bf-a88d76c7213f"
/dev/mmcblk0p3: PARTLABEL="fip" PARTUUID="18de6587-4f17-4e08-a6c9-d9d3d424f4c5"
/dev/mmcblk0p4: PARTLABEL="kernel" PARTUUID="971f7556-ef1a-44cd-8b28-0cf8100b9c7e"
/dev/mmcblk0p5: TYPE="squashfs" PARTLABEL="rootfs" PARTUUID="309a3e76-270b-41b2-b5d5-ed8154e7542b"
/dev/mmcblk0p6: PARTLABEL="kernel2" PARTUUID="9c17fbc2-79aa-4600-80ce-989ef9c95909"
/dev/mmcblk0p7: TYPE="squashfs" PARTLABEL="rootfs2" PARTUUID="f19609c8-f7d3-4ac6-b93e-7fd9fad4b4af"
/dev/mmcblk0p8: LABEL="rootfs_data" UUID="4959b647-3da7-464b-9b69-6c46b2e762dc" BLOCK_SIZE="4096" TYPE="f2fs" PARTLABEL="rootfs_data" PARTUUID="a4a43b93-f17d-43e2-b7a7-df0bdf610c77"
/dev/mmcblk0p9: LABEL="plugins" UUID="7ae9801f-4dcf-4c79-9c7f-eaefc65f767a" BLOCK_SIZE="1024" TYPE="ext4" PARTLABEL="plugins" PARTUUID="518c1031-c234-4d49-8301-02e7ebe31231"
/dev/mmcblk0p10: TYPE="squashfs" PARTLABEL="fwk" PARTUUID="6e2bd585-7b0b-45b5-a8a1-4cf5436b1f73"
/dev/mmcblk0p11: TYPE="squashfs" PARTLABEL="fwk2" PARTUUID="fd8708ae-59c7-4ed5-a467-54bfe357cb48"
/dev/mmcblk0p12: LABEL="extend" UUID="a2b01ad1-8504-4c5f-a93a-58a6046e46bc" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="data" PARTUUID="3c058515-54c3-452f-9b87-7a4f957b5cd1"
```

- ### 1.备份原厂分区
只需要备份gpt到mmcblk0p11 fwk2分区即可，最后一个mmcblk0p12 data分区太大不备份了。  
因为rootfs_data分区比较大，所以先备份到/mnt/mmcblk0p12目录，再用WinSCP下载下来。  
当然也可以压缩这个分区备份到tmp文件夹下，再用WinSCP下载下来。  

如果原厂是新版固件，无法解锁SSH，使用解锁telnet的配置文件解锁telnet后，也可以使用下面命令备份分区，但是先不下载下来，后面刷闭源固件不要刷gpt分区表，先挂载最后那个分区下载下来。  
telnet登录路由器，协议选telnet，地址192.168.10.1，端口23，直接点连接，账号密码都是没有的。  

提示：bl2在/dev/mmcblk0boot0，uboot在fip分区。  
unpartitioned.bin是全0的空白文件，是为了后面可以使用备份的分区按顺序直接合并得到一个eMMC img镜像。  
除更换eMMC，这个img基本用不到，不过还是全部分区备份为好。  
**注意：放在一起的命令全部复制粘贴执行，sync也一起复制，最后的时候回车执行sync即可，下同，不再赘述。**  
**这行sync命令主要是为了方便多行命令一起复制粘贴执行，不会遗漏上面的命令。**  

直接复制下面全部命令，粘贴执行即可：  
```
dd if=/dev/mmcblk0boot0 bs=512 count=2048 of=/mnt/mmcblk0p12/boot0_bl2.bin conv=fsync
dd if=/dev/mmcblk0 bs=512 count=34 of=/mnt/mmcblk0p12/mmcblk0_GPT.bin conv=fsync
dd if=/dev/mmcblk0 bs=512 skip=34 count=8158 of=/mnt/mmcblk0p12/mmcblk0_unpartitioned.bin conv=fsync
dd if=/dev/mmcblk0p1 of=/mnt/mmcblk0p12/mmcblk0p1_u-boot-env.bin conv=fsync
dd if=/dev/mmcblk0p2 of=/mnt/mmcblk0p12/mmcblk0p2_factory.bin conv=fsync
dd if=/dev/mmcblk0p3 of=/mnt/mmcblk0p12/mmcblk0p3_fip.bin conv=fsync
dd if=/dev/mmcblk0p4 of=/mnt/mmcblk0p12/mmcblk0p4_kernel.bin conv=fsync
dd if=/dev/mmcblk0p5 of=/mnt/mmcblk0p12/mmcblk0p5_rootfs.bin conv=fsync
dd if=/dev/mmcblk0p6 of=/mnt/mmcblk0p12/mmcblk0p6_kernel2.bin conv=fsync
dd if=/dev/mmcblk0p7 of=/mnt/mmcblk0p12/mmcblk0p7_rootfs2.bin conv=fsync
dd if=/dev/mmcblk0p8 of=/mnt/mmcblk0p12/mmcblk0p8_rootfs_data.bin conv=fsync
dd if=/dev/mmcblk0p9 of=/mnt/mmcblk0p12/mmcblk0p9_plugins.bin conv=fsync
dd if=/dev/mmcblk0p10 of=/mnt/mmcblk0p12/mmcblk0p10_fwk.bin conv=fsync
dd if=/dev/mmcblk0p11 of=/mnt/mmcblk0p12/mmcblk0p11_fwk2.bin conv=fsync
sync
```
耐心等待执行完成，最后一行sync回车执行即可，注意看最后一个fwk2分区是否备份完成。  
然后使用WinSCP之类的软件登录路由器，到/mnt/mmcblk0p12下载下来保存到电脑。  
WinScp软件登录路由器，协议SCP，IP 192.168.10.1，端口22，点击高级，高级站点设置-连接 去掉勾选“优化连接缓冲大小”，再点击登录。  

- ### 2.刷uboot：
因为没有像京东云百里那样锁bl2，所以这里只刷uboot就行了。  
RAX3000M算力版的uboot是mt7981_cmcc_rax3000m-emmc-fip_legacy-and-fit_20241007.bin  
RAX3000Z增强版的uboot是mt7981_cmcc_xr30-emmc-fip_legacy-and-fit_20241007.bin  

如果原厂是新版固件，无法解锁SSH，使用解锁telnet的配置文件解锁telnet后，设置电脑网卡为固定IP 192.168.10.2/24（注意只使用一个网卡，无线也不要连接），然后打开hfs(HTTP File Server)软件，将对应uboot文件拖拽到软件，然后使用下面对应的命令下载到/tmp目录：
```
wget -P /tmp http://192.168.10.2/mt7981_cmcc_rax3000m-emmc-fip_legacy-and-fit_20241026.bin
wget -P /tmp http://192.168.10.2/mt7981_cmcc_xr30-emmc-fip_legacy-and-fit_20241026.bin
```
如果是解锁了SSH则直接WinSCp之类的软件上传对应机型的单分区uboot文件到tmp文件夹。  
SSH输入命令验证md5：  
```
md5sum /tmp/mt7981_cmcc_*fip*.bin
```
2024.10.26版的uboot，是编译输出的fip文件刷入fip分区后的分区备份，所以有2MB大小，md5sum是：  
```
root@RAX3000M:~# md5sum /tmp/mt7981_cmcc_*fip*.bin
26ab5703bc760e5ec1e15815bc583dfd  /tmp/mt7981_cmcc_rax3000m-emmc-fip_legacy-and-fit_20241026.bin
2946aae3df18ee8b3f207ce1aee4fbef  /tmp/mt7981_cmcc_xr30-emmc-fip_legacy-and-fit_20241026.bin
```
核对上传uboot的md5正常后，输入命令刷写uboot所在的fip分区。  
RAX3000M eMMC算力版用这个命令：  
```
dd if=/tmp/mt7981_cmcc_rax3000m-emmc-fip_legacy-and-fit_20241026.bin of=$(blkid -t PARTLABEL=fip -o device) conv=fsync
```
RAX3000Z增强版用这个命令：  
```
dd if=/tmp/mt7981_cmcc_xr30-emmc-fip_legacy-and-fit_20241026.bin of=$(blkid -t PARTLABEL=fip -o device) conv=fsync
```
验证fip分区的md5和刷入文件一样即可，输入命令：  
```
md5sum $(blkid -t PARTLABEL=fip -o device)
```
RAX3000M eMMC算力版：  
```
root@RAX3000M:~# md5sum $(blkid -t PARTLABEL=fip -o device)
26ab5703bc760e5ec1e15815bc583dfd  /dev/mmcblk0p3
```
RAX3000Z增强版：  
```
root@XR30:~# md5sum $(blkid -t PARTLABEL=fip -o device)
2946aae3df18ee8b3f207ce1aee4fbef  /dev/mmcblk0p3
```
到这里uboot已经刷好了，可以断电重启，进uboot刷我提供的ImmortalWrt固件，然后接着刷gpt分区表。  

注：如果是从ImmortalWrt天灵单分区分区表或OpenWrt、ImmortalWrt主线分区表刷uboot，这里验证fip分区的md5是不一样的。  
因为他们的分区表把原厂2M的fip分区扩大到了4M，我这个分区表还是保持fip为2M。  
可以临时用下面命令验证fip分区数据的md5，和上面一样即可：  
```
dd if=$(blkid -t PARTLABEL=fip -o device) bs=512 count=4096 | md5sum 
```
后面再刷我的gpt分区表，fip分区会变为2M，重启新的分区表生效后，再验证分区的md5就会和我的一样了。  

天灵和大雕的刷机命令是直接使用偏移量，因为fip分区偏移量不变，所以不用管设备号。  
我上面刷uboot的命令自动找fip分区所在设备号，也不用你管设备号，可以直接用。  
更新uboot建议使用我教程的命令，或者直接进Uboot Web failsafe UI（简称uboot webui）里面更新即可。bl2一般不需要再更新了。  

- ### 3.刷gpt分区表
原厂系统中fdisk写入修复分区表会报错，我建议在刷好uboot后直接断电按reset进uboot，刷一个小于60MB的op后再刷分区表。  
建议用刷机教程中我提供的ImmortalWrt闭源固件，地址192.168.1.1，已集成sgdisk，后面新建分区需要用到。如果用其他固件请自行安装sgdisk。  
电脑网卡设置固定IP 192.168.1.2/24，连接网线到路由器lan口，路由上电按reset按键，等待灯变为蓝色，说明uboot webui已启动，可以松开按钮。  
浏览器打开192.168.1.1，上传固件刷写成功后绿灯会亮3秒，然后重启。注意：其他大佬的uboot可能指示灯不一样。  
此时电脑ip和dns可以设置回自动获取，然后等待系统启动后再操作刷gpt分区表。  

如果原厂是新版固件，无法解锁SSH，使用解锁telnet的配置文件解锁telnet，这里先不要刷gpt分区表，查看挂载点，挂载最后那个大分区，然后使用WinSCP之类的软件，将备份的分区下载下来，再进行刷gpt分区表。  

RAX3000M eMMC算力版和RAX3000Z增强版的gpt分区表通用。  
我的gpt分区表没有最后一个data大分区，需要在刷完分区表后使用sgdisk命令新建data分区。 
gpt分区表文件名中rootfs512M_production512M代表rootfs和production分区分别都是512M，依次类推。  
kernel+rootfs分区用于21.02闭源固件(.bin格式Legacy image)，production分区用于openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)。  
这个rootfs/production大小就是固件+overlay的大小，overlay近似是刷固件后剩余空间（软件包空间）大小，建议使用rootfs512M/production512M的分区表，当然也可选择自己需要大小的分区表。  
因为刷分区表改变了后面的分区的偏移量，所以后面分区的数据就不能识别了。  

上传你需要rootfs/production大小的gpt分区表文件到路由器/tmp目录，先验证md5：  
```
md5sum /tmp/rax3000m-emmc_xr30-emmc_*gpt.bin
```
```
root@ImmortalWrt:~# md5sum /tmp/rax3000m-emmc_xr30-emmc_*gpt.bin
e447f6f88bb8262055a9bd6547ce54df  /tmp/rax3000m-emmc_xr30-emmc_rootfs1024M_production1024M-gpt.bin
fa05fab1fe5fdd08324a9552fd68f312  /tmp/rax3000m-emmc_xr30-emmc_rootfs256M_production256M-gpt.bin
ccfd75bea7d8d2f4d5d75fc2d139cd8a  /tmp/rax3000m-emmc_xr30-emmc_rootfs512M_production512M-gpt.bin
```
你上传的文件的md5信息和上面对应文件的md5对比，没问题即可。  
下面的命令以rootfs/production512M的分区表为例，如果换其他的分区表，只修改if参数中的gpt分区表文件名即可，其他不要改。  
第1条dd命令是写入gpt分区表文件到/dev/mmcblk0的前34个扇区  
第2条sgdisk命令是用未分配空间新建data分区，-1G代表末尾的1G空间留白，可自行调整  
第3条sync命令主要是为了方便多行命令一起复制粘贴执行，不会遗漏上面的命令  
接着一起复制下面3条命令，一起粘贴执行： 
```
dd if=/tmp/rax3000m-emmc_xr30-emmc_rootfs512M_production512M-gpt.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
sgdisk -e -n 0:0:-1G -c 0:data -t 0:0FC63DAF-8483-4772-8E79-3D69D8477DE4 -u 0:3C058515-54C3-452F-9B87-7A4F957B5CD1 -p /dev/mmcblk0
sync
```
你会看到如下输出：  
```
root@ImmortalWrt:~# dd if=/tmp/rax3000m-emmc_xr30-emmc_rootfs512M_production512M-gpt.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
34+0 records in
34+0 records out
root@ImmortalWrt:~# sgdisk -e -n 0:0:-1G -c 0:data -t 0:0FC63DAF-8483-4772-8E79-3D69D8477DE4 -u 0:3C058515-54C3-452F-9B87-7A4F957B5CD1 -p /dev/mmcblk0
Setting name!
partNum is 6
Disk /dev/mmcblk0: 120832000 sectors, 57.6 GiB
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): 2BD17853-102B-4500-AA1A-8A21D4D7984D
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 120831966
Partitions will be aligned on 1024-sector boundaries
Total free space is 2105310 sectors (1.0 GiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   1            8192            9215   512.0 KiB   8300  u-boot-env
   2            9216           13311   2.0 MiB     8300  factory
   3           13312           17407   2.0 MiB     8300  fip
   4           17408           82943   32.0 MiB    8300  kernel
   5           82944         1131519   512.0 MiB   8300  rootfs
   6         1131520         2180095   512.0 MiB   FFFF  production
   7         2180096       120831966   56.6 GiB    8300  data
Warning: The kernel is still using the old partition table.
The new table will be used at the next reboot or after you
run partprobe(8) or kpartx(8)
The operation has completed successfully.
root@ImmortalWrt:~# sync
root@ImmortalWrt:~# 
```
dd写入没有报错，sgdisk最后输出successfully即可。如果分区表明显不一样或有错误则及时排错，重新刷。  
检查第5、6分区rootfs、production是分区表设置的大小，比如rootfs/production512M的分区表rootfs/production就是512MB。  
检查第7分区data大小接近整个eMMC大小，比如64G eMMC，data分区有56GB左右。  

建议此时备份下载修改后的分区表，以后有问题进不了系统，可以直接uboot刷这个分区表。  
当然重刷分区表后再新建分区也行，一样的。  
```
dd if=/dev/mmcblk0 bs=512 count=34 of=/tmp/mmcblk0_GPT_sgdisk.bin
```
都没有问题可以断电，按reset上电进uboot刷固件了。  

##【刷分区表的一点小提示】##  
不建议用diskman磁盘管理修改分区，可能会导致系统不能启动。建议用fdisk、gdisk之类的工具修改分区。  
如果不慎修改后系统不能启动，可以进入uboot，浏览器输入 http://192.168.1.1/gpt.html 重新刷正常的gpt分区表即可。  

如果在uboot或系统中更换了其他分区表，但又不需要新建分区，这种情况建议在系统中使用fdisk或者sgdisk（一般需要先安装）单独保存下分区表，这样在diskman那里显示才正确：  
例如系统中更换gpt分区表：  
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
gpt分区表的最大扇区数不能大于eMMC的物理最大扇区数，小于等于则没问题。比如128G的eMMC刷64G的分区表可以，刷256G的分区表会出错。  
mt798x eMMC机子的bl2在boot0硬件分区，不受userdata硬件分区的gpt分区表影响，即使gpt坏了也可以启动uboot，所以比较抗揍。  
比如百里测试刷最大扇区数大于eMMC扇区数的分区表也能启动uboot，只是固件启动会报错，可以进uboot重新刷正常的分区表。  
不过高通ipq60xx eMMC机子SBL是在userdata硬件分区中由gpt分区表划分出来的第一个软件分区，会受到gpt分区表的影响。  
比如京东云AX1800 Pro亚瑟测试直接刷最大扇区数大于eMMC扇区数的分区表会砖，需要USB救砖。  

同时如果最后一个大的分区超过了eMMC的扇区数，fdisk、parted、gdisk这些工具并不能直接修复，仍然需要删除新建。  

基于这两个原因，我改的分区表都采用天灵大佬的gpt分区表的做法，不保留最后一个最大的分区。  
这样的分区表只包含前面的小分区，扇区总数也不会超过4G，所以适用所有大于4G的eMMC。  
刷好我改分区表后，使用sgdisk用未分配空间新建一个分区，并还原分区的type code和UUID，这样分区和原厂分区是完全一样的。  

- ### 4.uboot刷固件、格式化data分区和切换固件
我改的这个uboot不支持DHCP，电脑需要设置ip 192.168.1.2/24，连接网线到路由器lan口，路由上电按reset，等待灯变为蓝色，说明uboot webui已启动，可以松开按钮，浏览器打开192.168.1.1，上传固件刷写成功后绿灯会亮3秒，然后重启。注意：其他大佬的uboot可能指示灯不一样。  
我改的这个uboot是2024.10.26编译的：  
RAX3000M算力版：U-Boot 2022.07-rc3 (Oct 26 2024 - 22:24:03 +0800)  
RAX3000Z增强版：U-Boot 2022.07-rc3 (Oct 26 2024 - 22:24:13 +0800)  

进入uboot webui页面后，最下方会显示这个编译日期，可以作为判断是否刷的是我改的uboot的标识。  
uboot不仅可以刷固件，还可以更新bl2、uboot和gpt，打开相应网页即可，非必要不需要更新：  
http://192.168.1.1                  刷写固件  
http://192.168.1.1/uboot.html       刷写uboot  
http://192.168.1.1/bl2.html         刷写bl2，注意刷写eMMC的bl2文件不大于1MB  
http://192.168.1.1/gpt.html         刷写eMMC机型的gpt分区表  
http://192.168.1.1/simg.html        刷写single image镜像（新增功能）  
http://192.168.1.1/initramfs.html   刷写内存启动固件initramfs  
注意：刷写bl2、gpt、simg不会验证文件，请一定做好原机备份并确认上传文件的有效性，特别是simg！！！  
关于single image：  
eMMC的是从gpt到最后一个分区的合并镜像，只合并到fip分区也可，不包含bl2，bl2需要单独刷写  
注意：eMMC从gpt到第一个分区间有段空白也要合并在内，请用我教程备份的分区bin文件进行合并  

uboot刷好第三方OP系统后，SSH登录用命令格式化下最后一个data分区。  
```
mkfs.ext4 $(blkid -t PARTLABEL=data -o device)
```
需要把data分区挂载给docker，则在系统->挂载点菜单，添加挂载点，UUID选择最大那个分区，我的分区表最大分区对应的是mmcblk0p7，输入自定义挂载位置/opt，回车，然后保存，再在外层点保存并应用，最后重启系统即可。  
最后检查系统->挂载点菜单，已挂载的文件系统中，挂载点/overlay对应的文件系统：  
刷写master开源固件后，/overlay对应的文件系统为/dev/fitrw  
刷写23.05开源固件后，/overlay对应的文件系统为/dev/mmcblk0p66  
刷写闭源固件后，/overlay对应的文件系统为/dev/loop0  
如果没有重新在备份与升级菜单升级下固件，直至有。  

直接uboot刷闭源固件(.bin格式Legacy image)或者openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)，可以直接启动。  
【注意】openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)固件第一次启动有点慢，特别是集成docker的固件，第一次启动可能需要5分钟，耐心等待，后面再启动就快了。  
【注意】由于主线RAX3000M-NAND和RAX3000M-eMMC使用all in fit，一个固件集合了NAND和eMMC固件，启动时需要选择对应的fdt才可正常启动eMMC的固件。我已通过uboot自动判断，如果从kernel分区启动闭源固件(.bin格式Legacy image)则删除这个环境变量，如果从production分区启动主线master/23.05分支固件(.itb格式FIT image)，则设置bootconf config-1#mt7981b-cmcc-rax3000m-emmc，这个是自动的。  
【注意】主线目前还没有XR30和RAX3000Z增强版（XR30-eMMC）支持，所以我设置bootconf直接使用config-1#mt7981b-cmcc-rax3000m-emmc，能支持主线RAX3000M-eMMC固件启动，但主线支持XR30-eMMC后是不能启动的，得修改uboot源码，改这个bootconf设置。XR30-eMMC比RAX3000M-eMMC少一个LED，XR30-eMMC的eMMC可以跑52MHz，RAX3000M-eMMC的eMMC跑26MHz。  

uboot刷机是不保留配置的，如果已经刷好两种固件不想重刷，可以在系统里修改环境变量，重启即可切换启动的固件，配置保留。  
当前在openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)，要切换到闭源固件(.bin格式Legacy image)  
运行下面命令修改环境变量，没有报错即可，然后reboot重启
```
cp /etc/fw_env.config /etc/fw_env.config.bak
echo -e "/dev/mmcblk0p1 0 0x80000" > /etc/fw_env.config
fw_setenv dual_boot.current_slot 0
cp /etc/fw_env.config.bak /etc/fw_env.config
```

当前在闭源固件(.bin格式Legacy image)，要切换到openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)  
运行下面命令修改环境变量，没有报错即可，然后reboot重启  
```
fw_setenv dual_boot.current_slot 1
```

- ### 5.刷回原厂
输入下面命令不报错即可：  
```
fw_setenv dual_boot.current_slot 0
```
回原厂需要先刷回备份分区表，恢复原厂的mmcblk0p9-11这三个分区，mmcblk0p12如果没有格式化需要格式化下。  
刷回原厂备份的gpt分区表：  
```
dd if=/tmp/mmcblk0_GPT.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync && echo -e 'w' | fdisk /dev/mmcblk0
```
刷好原厂分区表后，断电进uboot刷下OP固件。  

OP系统起来后还原plugins、fwk和fwk2分区：  
上传mmcblk0p9_plugins.bin、mmcblk0p10_fwk.bin和mmcblk0p11_fwk2.bin到/tmp目录，然后刷回去：  
```
dd if=/tmp/mmcblk0p9_plugins.bin of=$(blkid -t PARTLABEL=plugins -o device) conv=fsync
dd if=/tmp/mmcblk0p10_fwk.bin of=$(blkid -t PARTLABEL=fwk -o device) conv=fsync
dd if=/tmp/mmcblk0p11_fwk2.bin of=$(blkid -t PARTLABEL=fwk2 -o device) conv=fsync
```
接着格式化下data分区：  
```
umount $(blkid -t PARTLABEL=data -o device)
mkfs.ext4 -L extend $(blkid -t PARTLABEL=data -o device)
```
格式化后web页面挂载点那里，手动挂载/dev/mmcblk0p12到/mnt/mmcblk0p12，记住勾选启用，保存并应用。  
然后SSH输入命令在这个路径下新建一个ecmanager文件夹，这样就还原了所有分区了，SSH输入命令：  
```
mkdir /mnt/mmcblk0p12/ecmanager
```

刷回原厂uboot和固件：  
接着上传原厂mmcblk0p3_fip.bin、mmcblk0p4_kernel.bin、mmcblk0p5_rootfs.bin到tmp，刷写uboot设置从系统0启动，刷写kernel、rootfs并清空rootfs_data，为了保险kernel2、rootfs2也一并写入原厂固件：  
```
dd if=/tmp/mmcblk0p3_fip.bin of=$(blkid -t PARTLABEL=fip -o device) conv=fsync
fw_setenv dual_boot.current_slot 0
dd if=/tmp/mmcblk0p4_kernel.bin of=$(blkid -t PARTLABEL=kernel -o device) conv=fsync
dd if=/tmp/mmcblk0p5_rootfs.bin of=$(blkid -t PARTLABEL=rootfs -o device) conv=fsync
dd if=/tmp/mmcblk0p4_kernel.bin of=$(blkid -t PARTLABEL=kernel2 -o device) conv=fsync
dd if=/tmp/mmcblk0p5_rootfs.bin of=$(blkid -t PARTLABEL=rootfs2 -o device) conv=fsync
dd if=/dev/zero of=$(blkid -t PARTLABEL=rootfs_data -o device) conv=fsync
```
注意：dd: error writing '/dev/mmcblk0p8': No space left on device  
这个报错是正常的，不用管！！  

等待mmcblk0p8 rootfs_data分区刷完，刷完断电重启即可。  

- ### 6.串口TTL救砖
注意：mtk_uartboot文件夹下的bl2、fip只用于救砖，不要刷入正常机子。  
路由器断电，使用USB转TTL（建议使用3.3V电平的，推荐使用FT232RL）连接路由器串口TTL接口。  
运行串口TTL救砖文件夹下的“打开设备管理器命令.bat”，在打开的设备管理器中查看USB转TTL设备对应的COM口号。  
关闭可能占用该COM口的程序，运行“MT798X串口TTL救砖命令.bat”，输入该COM口号，选择正常波特率，然后选择对应机型的fip序号。  
脚本会调用mtk_uartboot加载fip-debrick-only的uboot到内存，该uboot是修改过mtkboardboot的专用uboot，会自动进入uboot webui，无需操作。  
不支持DHCP，请设置固定IP后访问相应的Web failsafe UI地址，Web failsafe UI启动后可以通过按Ctrl+C回到Uboot控制台。  
因为mtk_uartboot加载uboot是临时uboot，需要进入uboot webui对应页面重新刷写变砖的分区。  
针对eMMC机型有以下几个页面：  
http://192.168.1.1                  刷写固件，救砖一般不用  
http://192.168.1.1/uboot.html       刷写uboot  
http://192.168.1.1/bl2.html         刷写bl2，注意刷写eMMC的bl2文件不大于1MB  
http://192.168.1.1/gpt.html         刷写eMMC机型的gpt分区表  
http://192.168.1.1/simg.html        刷写single image镜像（新增功能）  
http://192.168.1.1/initramfs.html   刷写内存启动固件initramfs  
注意：刷写bl2、gpt、simg不会验证文件，请一定做好原机备份并确认上传文件的有效性，特别是simg！！！  
关于single image：  
eMMC的是从gpt到最后一个分区的合并镜像，只合并到fip分区也可，不包含bl2，bl2需要单独刷写  
注意：eMMC从gpt到第一个分区间有段空白也要合并在内，请用我教程备份的分区bin文件进行合并  

如果存储无线校准数据eeprom的factory分区刷没了，救砖刷固件后无线可能起不来，需要有线进系统恢复该分区。  
```
dd if=/tmp/mmcblk0p2_factory.bin of=$(blkid -t PARTLABEL=factory -o device) conv=fsync
```

- ### 关于52MHz频率固件
mt7981的eMMC接口最高可以跑52MHz，因为RAX3000M算力版的eMMC体质比较菜，跑52MHz固件会爆I/O error导致系统崩溃，所以原厂固件设置eMMC频率是26MHz，大佬们的固件默认也是26MHz，比较稳定。RAX3000Z增强版原厂系统给的是52MHz，使用52MHz固件没有问题。  
如果RAX3000M算力版想尝试eMMC 52MHz固件，大概率会I/O error，无解只能换eMMC，但是费用高不值得，还是建议26MHz固件即可。  
52MHz eMMC读写速度约45MB/s，26MHz约为20MB/s，使用上是感觉不出差别的。  

SSH输入命令查看是否有I/O error报错：  
```
dmesg | grep 'I/O error'
```
查看固件eMMC频率用命令：  
```
cat /sys/kernel/debug/mmc0/ios
```
