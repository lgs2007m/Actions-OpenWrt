最新教程和原厂固件下载链接：  
https://github.com/lgs2007m/Actions-OpenWrt/releases/tag/Router-Flashing-Files  

目录  
0.开SSH  
1.备份原厂分区  
2.刷bl2和uboot  
3.刷gpt分区表  
4.uboot刷固件、格式化storage分区和切换固件  
5.刷回原厂  
6.串口TTL救砖  

mt798x的fip分区实际上包含bl31+uboot，为了方便理解，这里的教程将fip直接称为uboot。  

本教程使用基于hanwckf大佬bl-mt798x仓库uboot-202206源码修改编译的bl2、uboot和gpt，不支持DHCP。  
目前已同时支持21.02闭源固件(.bin格式Legacy image)和openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)直接刷入启动，可在SSH修改环境变量，直接切换启动两种固件，无需重刷，配置保留。  

uboot及gpt源码请查看 https://github.com/lgs2007m/bl-mt798x/tree/emmc  
感谢天灵等一众大佬提供的FIT image支持，感谢hanwckf大佬的bl-mt798x项目。  

- ### 准备刷机文件和工具软件
最新刷机文件下载：https://github.com/lgs2007m/Actions-OpenWrt/releases/tag/Router-Flashing-Files  
SSH工具软件：Xshell https://pan.lanzoui.com/b0f19ry9g  或者putty https://www.423down.com/11333.html  
文件传输工具软件：WinSCP https://www.ghxi.com/winscp.html  

关于mt798x改内存：目前开源ATF 7981 DDR3最高512M，DDR4最高1G；7986 DDR3最高512M，DDR4 2G。  

- ### 0.开SSH
京东云AX6000百里没有软破解SSH，通过原厂系统升级官方放出的原生OP可获取SSH权限。  
原厂系统中升级官方原生OP：  
openwrt-re-cp-03-4.1.0.r4005-1287bf0122329d5c3acbb7198e04b1e4.bin  
注意：官方宣传升级原生OP会失去保修，请自行斟酌。  

升级系统重启完成后，使用SSH软件登录192.168.68.1，端口22，用户名root，没有密码。  
输入命令删除这两个环境变量：  
```
fw_setenv jdc_crc_version && fw_setenv jdc_opp_version
```
下面简单看下原厂分区的信息，不想了解的可以略过，直接跳到备份原厂分区部分。  
blkid命令可以直接使用，sgdisk和lsblk命令需要安装后才能使用。  
可以看到原厂有两个系统分区kernel、rootfs和kernel2、rootfs2，即双分区，共用一个50MB的rootfs_data。  
kernel和rootfs分区用于.bin格式Legacy image，kernel、kernel2都是16MB，rootfs、rootfs2都是50MB。  
固件中kernel一般占3MB左右，分区表kernel分区16MB完全够用，但是rootfs大小限制了原厂双分区分区表刷固件的大小。  
因此原厂双分区分区表下刷固件不能大于kernel+rootfs大小即53MB。  
因为原厂使用旧的mt7986-emmc.json来制作gpt分区表，所以gpt分区会在blkid第一个分区显示出来，即PMBR分区。  
同时下面的分区对应分区设备号，相比RAX3000M eMMC、GL-MT6000的分区设备号会加1。  
比如RAX3000M eMMC的fip分区的设备号是mmcblk0p3，百里的fip分区设备号则是mmcblk0p4。  
新的gpt分区表和RAX3000M eMMC、GL-MT6000都是使用新版json来制作，gpt分区不会显示出来。  
blkid是否显示gpt分区和设备号加1，不影响使用，系统是读取PARTLABEL来读写的。  

```
root@OpenWrt:~# blkid
/dev/mmcblk0p1: PTTYPE="PMBR"
/dev/mmcblk0p2: PARTLABEL="u-boot-env" PARTUUID="19a4763a-6b19-4a4b-a0c4-8cc34f4c2ab9"
/dev/mmcblk0p3: PARTLABEL="factory" PARTUUID="8142c1b2-1697-41d9-b1bf-a88d76c7213f"
/dev/mmcblk0p4: PARTLABEL="fip" PARTUUID="18de6587-4f17-4e08-a6c9-d9d3d424f4c5"
/dev/mmcblk0p5: PARTLABEL="kernel" PARTUUID="971f7556-ef1a-44cd-8b28-0cf8100b9c7e"
/dev/mmcblk0p6: TYPE="squashfs" PARTLABEL="rootfs" PARTUUID="309a3e76-270b-41b2-b5d5-ed8154e7542b"
/dev/mmcblk0p7: PARTLABEL="kernel2" PARTUUID="9c8e460f-7160-4c25-a420-e7deeb10d5d3"
/dev/mmcblk0p8: TYPE="squashfs" PARTLABEL="rootfs2" PARTUUID="508b8f82-164c-4898-8edc-adaa59438cd4"
/dev/mmcblk0p9: LABEL="rootfs_data" UUID="ea5ae1d2-cdc2-40c9-bada-0a9c0d8f63a6" BLOCK_SIZE="1024" TYPE="ext4" PARTLABEL="rootfs_data" PARTUUID="dd18c072-adb3-412b-bf97-37617b01adf3"
/dev/mmcblk0p10: UUID="4f3e32d7-cf18-40a9-a42d-0afa648c1513" BLOCK_SIZE="1024" TYPE="ext4" PARTLABEL="log" PARTUUID="2d18c070-adb6-412b-bf90-37617b01adf5"
/dev/mmcblk0p11: UUID="fac0a627-0346-4883-bea5-f0aefccb31aa" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="plugin" PARTUUID="3d18c075-adb0-412b-bf92-37617b01adf6"
/dev/mmcblk0p12: TYPE="swap" PARTLABEL="swap" PARTUUID="4d18c079-adb2-412b-bf93-37617b01adf7"
/dev/mmcblk0p13: UUID="a10bd4dd-7f44-4760-a1e9-51a71442922a" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="storage" PARTUUID="5d18c072-adb3-412b-bf95-37617b01adf8"
root@OpenWrt:~# sgdisk -p /dev/mmcblk0
Warning! Main partition table overlaps the first partition by 34 blocks!
You will need to delete this partition or resize it in another utility.
Disk /dev/mmcblk0: 241664000 sectors, 115.2 GiB
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): 2BD17853-102B-4500-AA1A-8A21D4D7984D
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 240615424
Partitions will be aligned on 1024-sector boundaries
Total free space is 8158 sectors (4.0 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   2            8192            9215   512.0 KiB   8300  u-boot-env
   3            9216           13311   2.0 MiB     8300  factory
   4           13312           17407   2.0 MiB     8300  fip
   5           17408           50175   16.0 MiB    8300  kernel
   6           50176          152575   50.0 MiB    8300  rootfs
   7          152576          185343   16.0 MiB    8300  kernel2
   8          185344          287743   50.0 MiB    8300  rootfs2
   9          287744          390143   50.0 MiB    8300  rootfs_data
  10          390144          524287   65.5 MiB    8300  log
  11          524288         2621439   1024.0 MiB  8300  plugin
  12         2621440         4718591   1024.0 MiB  8300  swap
  13         4718592       240615424   112.5 GiB   8300  storage
root@OpenWrt:~# lsblk
NAME         MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
mmcblk0      179:0    0 115.2G  0 disk 
├─mmcblk0p1  179:1    0    17K  0 part 
├─mmcblk0p2  179:2    0   512K  0 part 
├─mmcblk0p3  179:3    0     2M  0 part 
├─mmcblk0p4  179:4    0     2M  0 part 
├─mmcblk0p5  179:5    0    16M  0 part 
├─mmcblk0p6  179:6    0    50M  0 part 
├─mmcblk0p7  179:7    0    16M  0 part 
├─mmcblk0p8  259:0    0    50M  0 part /rom
├─mmcblk0p9  259:1    0    50M  0 part /overlay
├─mmcblk0p10 259:2    0  65.5M  0 part /log
├─mmcblk0p11 259:3    0     1G  0 part /opt
├─mmcblk0p12 259:4    0     1G  0 part [SWAP]
└─mmcblk0p13 259:5    0 112.5G  0 part /mnt/mmcblk0p13
mmcblk0boot0 179:8    0     4M  1 disk 
mmcblk0boot1 179:16   0     4M  1 disk 
```

- ### 1.备份原厂分区
只需要备份gpt到mmcblk0p12 swap分区即可，最后一个mmcblk0p13 storage分区太大不备份了。  
因为plugin、swap分区都有1G，比较大，所以先备份到挂载点/mnt/mmcblk0p13中，然后使用WinScp之类的软件登录下载下来。  

提示：bl2在/dev/mmcblk0boot0，uboot在fip分区。  
unpartitioned.bin是全0的空白文件，是为了后面可以使用备份的分区按顺序直接合并得到一个eMMC img镜像。  
除更换eMMC，这个img基本用不到，不过还是全部分区备份为好。  
**注意：放在一起的命令全部复制粘贴执行，sync也一起复制，最后的时候回车执行sync即可，下同，不再赘述。**  
**这行sync命令主要是为了方便多行命令一起复制粘贴执行，不会遗漏上面的命令。**  

直接复制下面全部命令，粘贴执行即可：  
```
dd if=/dev/mmcblk0boot0 bs=512 count=2048 of=/mnt/mmcblk0p13/mmcblk0boot0_bl2.bin conv=fsync
dd if=/dev/mmcblk0p1 of=/mnt/mmcblk0p13/mmcblk0p1_PMBR.bin conv=fsync
dd if=/dev/mmcblk0 bs=512 skip=34 count=8158 of=/mnt/mmcblk0p13/mmcblk0p1_unpartitioned.bin conv=fsync
dd if=/dev/mmcblk0p2 of=/mnt/mmcblk0p13/mmcblk0p2_u-boot-env.bin conv=fsync
dd if=/dev/mmcblk0p3 of=/mnt/mmcblk0p13/mmcblk0p3_factory.bin conv=fsync
dd if=/dev/mmcblk0p4 of=/mnt/mmcblk0p13/mmcblk0p4_fip.bin conv=fsync
dd if=/dev/mmcblk0p5 of=/mnt/mmcblk0p13/mmcblk0p5_kernel.bin conv=fsync
dd if=/dev/mmcblk0p6 of=/mnt/mmcblk0p13/mmcblk0p6_rootfs.bin conv=fsync
dd if=/dev/mmcblk0p7 of=/mnt/mmcblk0p13/mmcblk0p7_kernel2.bin conv=fsync
dd if=/dev/mmcblk0p8 of=/mnt/mmcblk0p13/mmcblk0p8_rootfs2.bin conv=fsync
dd if=/dev/mmcblk0p9 of=/mnt/mmcblk0p13/mmcblk0p9_rootfs_data.bin conv=fsync
dd if=/dev/mmcblk0p10 of=/mnt/mmcblk0p13/mmcblk0p10_log.bin conv=fsync
dd if=/dev/mmcblk0p11 of=/mnt/mmcblk0p13/mmcblk0p11_plugin.bin conv=fsync
dd if=/dev/mmcblk0p12 of=/mnt/mmcblk0p13/mmcblk0p12_swap.bin conv=fsync
sync
```
耐心等待执行完成，最后一行sync回车执行即可，注意看最后一个swap分区是否备份完成。  
然后使用WinSCP之类的软件登录路由器，到/mnt/mmcblk0p13目录下载下来保存到电脑。  
WinScp软件登录路由器，协议SCP，IP 192.168.68.1，端口22，点击高级，高级站点设置-连接 去掉勾选“优化连接缓冲大小”，再点击登录。  

注：/mnt/mmcblk0p13里的aiecpluginD、jdc_docker文件夹里面是跑分的缓存数据。  
如果不大，也可自行压缩后备份，刷机后直接恢复到storage分区，这样回原厂跑分直接用这些数据，可以更快恢复跑分。  
太大就不建议备份，回原厂后重新缓存即可。  

- ### 2.刷bl2和uboot
百里的bl2和uboot是开启了Secure Boot验证的，需要把bl2和uboot所在fip分区一起替换掉，不能只替换uboot！！！  
因为有些数据洁癖，我直接将编译得到的bl2二进制文件尾部填充0扩大至256KB，fip尾部填充0至2048KB。  
这样刷文件就可直接覆盖有数据部分，相当于清空分区再刷写，所以文件看着有点大。  
当然直接使用编译得到的原始文件也没问题刷写也可以。  

将bl2和uboot上传到路由器/tmp目录，SSH输入命令验证md5：  
```
md5sum /tmp/mt7986_jdcloud_re-cp-03*.bin
```
2024.10.10版bl2、uboot的md5值是：  
```
root@OpenWrt:~# md5sum /tmp/mt7986_jdcloud_re-cp-03*.bin
6c0d654a9dc261b769b472f1e3bb4df9  /tmp/mt7986_jdcloud_re-cp-03-bl2_20241010.bin
053cb614b1309f5d04544fb3380548ed  /tmp/mt7986_jdcloud_re-cp-03-fip_legacy-and-fit_20241010.bin
```
核对md5正常后，先输入下面命令切换到shell (ash)：  
```
ash
```
然后一起复制下面命令粘贴执行，刷写bl2和uboot：  
```
echo 0 > /sys/block/mmcblk0boot0/force_ro
dd if=/tmp/mt7986_jdcloud_re-cp-03-bl2_20241010.bin of=/dev/mmcblk0boot0 conv=fsync
echo 1 > /sys/block/mmcblk0boot0/force_ro
dd if=/tmp/mt7986_jdcloud_re-cp-03-fip_legacy-and-fit_20241010.bin of=$(blkid -t PARTLABEL=fip -o device) conv=fsync
sync
```
最后一行sync回车执行，刷写完没有报错，则检查下分区的md5值，和我一样即可，不一样就重新刷，不能重启！！  
```
md5sum /dev/mmcblk0boot0 && md5sum $(blkid -t PARTLABEL=fip -o device)
```
输出结果和我一样即可：  
```
root@OpenWrt:~# md5sum /dev/mmcblk0boot0 && md5sum $(blkid -t PARTLABEL=fip -o device)
7dfc7a41871f6dcfd8fbcdc23706ee5c  /dev/mmcblk0boot0
053cb614b1309f5d04544fb3380548ed  /dev/mmcblk0p4
```
到这里bl2和uboot已经刷好了，不要重启，接着刷gpt分区表。  

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
原生OP没有sgdisk，刷gpt分区表前，先安装sgdisk以便后面编辑分区表。  
将sgdisk文件夹里面的sgdisk_1.0.6-1_aarch64_cortex-a53.ipk上传/tmp目录，然后SSH运行下面命令安装：  
```
opkg install -d root /tmp/sgdisk_1.0.6-1_aarch64_cortex-a53.ipk
```
我的百里gpt分区表保留了原厂跑分的分区log、plugin、swap，没有最后一个storage大分区，需要在刷完分区表后使用sgdisk命令新建storage分区。  
gpt分区表文件名中rootfs512M_production512M代表rootfs和production分区分别都是512M，依次类推。  
kernel+rootfs分区用于21.02闭源固件(.bin格式Legacy image)，production分区用于openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)。  
这个rootfs/production大小就是固件+overlay的大小，overlay近似是刷固件后剩余空间（软件包空间）大小，建议使用rootfs512M/production512M的分区表，当然也可选择自己需要大小的分区表。  
因为刷分区表改变了后面的分区的偏移量，所以后面分区的数据就不能识别了。  
如果不需要回原厂跑分，直接使用RAX3000M-eMMC/XR30-eMMC的分区表也可以，新建和格式化最后一个storage分区的命令建议还是用百里的。  
如果要回原厂跑分，后面会讲到需要先恢复log、plugin、swap，新建并格式化最后一个storage分区。  

上传你需要rootfs/production大小的gpt分区表文件到路由器/tmp目录，先验证md5：  
```
md5sum /tmp/jdcloud_re-cp-03_*gpt.bin
```
```
root@OpenWrt:~# md5sum /tmp/jdcloud_re-cp-03_*gpt.bin
823e50e29dd27b55ce11a3757e676da7  /tmp/jdcloud_re-cp-03_rootfs1024M_production1024M-gpt.bin
2d57350e2f5da3a7c7fbc2b6a196a82f  /tmp/jdcloud_re-cp-03_rootfs256M_production256M-gpt.bin
3abe28bfa7b6072b05059c6cdf292a6f  /tmp/jdcloud_re-cp-03_rootfs512M_production512M-gpt.bin
```
你上传的文件的md5信息和上面对应文件的md5对比，没问题即可。  
下面的命令以rootfs/production512M的分区表为例，如果换其他的分区表，只修改if参数中的gpt分区表文件名即可，其他不要改。  
第1条dd命令是写入gpt分区表文件到/dev/mmcblk0的前34个扇区  
第2条sgdisk命令是用未分配空间新建storage分区，-1G代表末尾的1G空间留白，可自行调整  
第3条sync命令主要是为了方便多行命令一起复制粘贴执行，不会遗漏上面的命令  
接着一起复制下面3条命令，一起粘贴执行： 
```
dd if=/tmp/jdcloud_re-cp-03_rootfs512M_production512M-gpt.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
sgdisk -e -n 0:0:-1G -c 0:storage -t 0:0FC63DAF-8483-4772-8E79-3D69D8477DE4 -u 0:5D18C072-ADB3-412B-BF95-37617B01ADF8 -p /dev/mmcblk0
sync
```
最后一行sync回车执行，你会看到如下输出：  
```
root@OpenWrt:~# dd if=/tmp/jdcloud_re-cp-03_rootfs512M_production512M-gpt.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
34+0 records in
34+0 records out
root@OpenWrt:~# sgdisk -e -n 0:0:-1G -c 0:storage -t 0:0FC63DAF-8483-4772-8E79-3D69D8477DE4 -u 0:5D18C072-ADB3-412B-BF95-37617B01ADF8 -p /dev/mmcblk0
Setting name!
partNum is 9
Disk /dev/mmcblk0: 241664000 sectors, 115.2 GiB
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): 2BD17853-102B-4500-AA1A-8A21D4D7984D
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 241663966
Partitions will be aligned on 1024-sector boundaries
Total free space is 2105310 sectors (1.0 GiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   1            8192            9215   512.0 KiB   8300  u-boot-env
   2            9216           13311   2.0 MiB     8300  factory
   3           13312           17407   2.0 MiB     8300  fip
   4           17408           50175   16.0 MiB    8300  kernel
   5           50176         1098751   512.0 MiB   8300  rootfs
   6         1098752         2147327   512.0 MiB   FFFF  production
   7         2147328         2281471   65.5 MiB    8300  log
   8         2281472         4378623   1024.0 MiB  8300  plugin
   9         4378624         6475775   1024.0 MiB  8300  swap
  10         6475776       239566814   111.1 GiB   8300  storage
Warning: The kernel is still using the old partition table.
The new table will be used at the next reboot or after you
run partprobe(8) or kpartx(8)
The operation has completed successfully.
root@OpenWrt:~# sync
root@OpenWrt:~# 
```
dd写入没有报错，sgdisk最后输出successfully即可。如果分区表明显不一样或有错误则及时排错，重新刷。  
检查第5、6分区rootfs、production是分区表设置的大小，比如rootfs/production512M的分区表rootfs/production就是512MB。  
检查第9分区storage大小接近整个eMMC大小，比如128G eMMC，storage分区有110GB左右。  

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

- ### 4.uboot刷固件、格式化storage分区和切换固件
我改的这个uboot不支持DHCP，电脑需要设置ip 192.168.1.2/24，连接网线到路由器lan口，路由上电按reset，等待灯变为蓝色，说明uboot webui已启动，可以松开按钮，浏览器打开192.168.1.1，上传固件刷写成功后绿灯会亮3秒，然后重启。注意：其他大佬的uboot可能指示灯不一样。  
我改的这个uboot是2024.10.10编译的 U-Boot 2022.07-rc3 (Oct 10 2024 - 14:23:13 +0800)  
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

uboot刷好第三方OP系统后，SSH登录用命令格式化下最后一个storage分区。  
```
mkfs.ext4 $(blkid -t PARTLABEL=storage -o device)
```
如果要把storage分区挂载给docker，则在系统->挂载点菜单，添加挂载点，UUID选择最大那个分区，我的分区表最大分区对应的是mmcblk0p10，输入自定义挂载位置/opt，回车，然后保存，再在外层菜单点保存并应用，最后重启系统即可。  
打开系统->挂载点，查看交换分区，如果是自动挂载的固件，可以看到/dev/mmcblk0p9挂载为swap的分区，可以取消勾选，然后保存并应用，因为固件一般已经使用zram了。  
如果sawp和zram都用，首页概览交换分区那里显示的是1.5G，取消swap的挂载则显示0.5G。  
最后检查系统->挂载点菜单，已挂载的文件系统中，挂载点/overlay对应的文件系统：  
刷写master开源固件后，/overlay对应的文件系统为/dev/fitrw  
刷写23.05开源固件后，/overlay对应的文件系统为/dev/mmcblk0p66  
刷写闭源固件后，/overlay对应的文件系统为/dev/loop0  
如果没有重新在备份与升级菜单升级下固件，直至有。  

直接uboot刷闭源固件(.bin格式Legacy image)或者openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)，可以直接启动。  
【注意】openwrt、immortalwrt主线master/23.05分支固件(.itb格式FIT image)固件第一次启动有点慢，特别是集成docker的固件，第一次启动可能需要5分钟，耐心等待，后面再启动就快了。  

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
因为官方原厂固件是双分区固件(.bin格式Legacy image)，兼容单分区，所以直接uboot刷原厂固件即可，什么都不用换，但是要跑分需要恢复跑分的分区。  
刷回原厂后想要再刷第三方OP则直接uboot刷即可，什么都不用换，自由切换固件。  

教程压缩包中有京东云AX6000百里官方固件JDC04-4.3.0.r4204。  
下面开始恢复log、plugin、swap分区。  
注意：log分区变为了mmcblk0p7，plugin变为mmcblk0p8，swap变为了mmcblk0p9，storage分区变为了mmcblk0p10。  
去系统->挂载点菜单，拉到下方的挂载点，挂载/dev/mmcblk0p10到/mnt/mmcblk0p10，记得勾选启用并保存应用。  

WinSCP之类软件上传备份好的mmcblk0p10_log.bin、mmcblk0p11_plugin.bin和mmcblk0p12_swap.bin到/mnt/mmcblk0p10，使用下面命令刷回：  
```
dd if=/mnt/mmcblk0p10/mmcblk0p10_log.bin of=$(blkid -t PARTLABEL=log -o device) conv=fsync
dd if=/mnt/mmcblk0p10/mmcblk0p11_plugin.bin of=$(blkid -t PARTLABEL=plugin -o device) conv=fsync
dd if=/mnt/mmcblk0p10/mmcblk0p12_swap.bin of=$(blkid -t PARTLABEL=swap -o device) conv=fsync
```
刷好后可以删除上传的文件，当然swap分区按理说可以运行命令新建，不过我还是用备份直接恢复分区：  
```
mkswap $(blkid -t PARTLABEL=swap -o device)
swapon $(blkid -t PARTLABEL=swap -o device)
```

恢复完分区后，web不保留配置升级或直接uboot刷回官方固件，系统启动后打开无线宝app，存储设置内置存储为本地网盘，然后直接恢复出厂，启动后再进入app设置内置存储为智能加速服务。  
恢复智能跑分服务后，可能无线宝app中的服务状态一直在自动修复，灯是蓝色的不能马上变绿灯，需要等待，我试的情况是有可能需要1-2个小时才恢复绿灯。  
如果刷回原厂超过2小时跑分服务一直在修复，可以尝试重新刷log、plugin、swap分区。  
再重试设置内置存储为本地网盘，然后直接恢复出厂，系统启动后再设置内置存储为智能加速服务。  
如何恢复分区回原厂快速开始跑分，我没有摸索出规律，所以得大家自己多尝试。  

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
dd if=/tmp/mmcblk0p3_factory.bin of=$(blkid -t PARTLABEL=factory -o device) conv=fsync
```
