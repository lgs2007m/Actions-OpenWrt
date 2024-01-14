目前遇到的MT798X的eMMC的路由器京东云百里AX6000、CMCC RAX3000M eMMC算力版，都是闪存只有eMMC的。

下面以CMCC RAX3000M eMMC算力版更换eMMC为例（京东云百里方法相同）：  
bl2默认在mmcblk0boot0这个硬件分区，uboot在mmcblk0的软件分区中的fip分区。  
当我们想要换eMMC的时候，需要有ext_csd信息、mmcblk0boot0分区、mmcblk0_GPT到mmcblk0p11_fwk2分区备份。  
这个是完全恢复原厂系统，如果恢复op系统更简单，直接用刷机的gpt分区表和fip替换原厂的gpt分区表和fip分区文件，后面部分只需要合并mmcblk0_GPT到mmcblk0p3_fip即可。
更换好eMMC直接进uboot webui刷op固件即可。
如果你有eMMC编程器，直接用编程器把mmcblk0boot0、ext_csd、mmcblk0_GPT到mmcblk0p11_fwk2还原回去即可。  

我只有RTS5170芯片的读卡器，支持boot0、1和ext_csd读写，所以我单独还原这些文件。  

更换相同大小64G eMMC。如果更换不同大小eMMC需要DG修复下分区表或者使用atf源码中的gpt_editor自己修改相应大小的分区表，替换原厂的。  

下面这个备份文件就是bl2，RAX3000M的BL2没有锁，所以直接用原厂的即可：  
注：百里的bl2和fip都是有secure boot锁的，要配套使用，或者直接全部替换no secure boot的。
```
boot0_bl2.bin
```
将下面已备份的分区按顺序合并为一个bin文件，就是一个eMMC的镜像（当然没有最大的分区data分区）以便写入。  
注：unpartitioned.bin是4079KB大小的全0文件，和17KB的GPT组成的偏移量4096KB，正好是u-boot-env分区的偏移量。
```
mmcblk0_GPT.bin
mmcblk0_unpartitioned.bin
mmcblk0p1_u-boot-env.bin
mmcblk0p2_factory.bin
mmcblk0p3_fip.bin
mmcblk0p4_kernel.bin
mmcblk0p5_rootfs.bin
mmcblk0p6_kernel2.bin
mmcblk0p7_rootfs2.bin
mmcblk0p8_rootfs_data.bin
mmcblk0p9_plugins.bin
mmcblk0p10_fwk.bin
mmcblk0p11_fwk2.bin
```

将新的eMMC通过转接板接入RTS5170读卡器，插上Ubuntu中，运行命令首先查看eMMC是否识别到了：  
```
fdisk -x /dev/mmcblk0
```
识别到后安装mmc-utils，输入命令写入bl2和并设置ext_csd信息从boot0启动：  
```
sudo -i
echo 0 > /sys/block/mmcblk0boot0/force_ro
dd if=boot0_bl2.bin of=/dev/mmcblk0boot0
echo 1 > /sys/block/mmcblk0boot0/force_ro
mmc bootbus set single_backward x1 x1 /dev/mmcblk0
mmc bootpart enable 1 1 /dev/mmcblk0
mmc hwreset enable /dev/mmcblk0
```
注：上面写入boot0和mmc设置命令也可以用于op系统中。  

写完之后用命令查看设置的ext_csd是否和原厂相同：  
```
mmc extcsd read /dev/mmcblk0 | grep -e BOOT_BUS_CONDITIONS -e PARTITION_CONFIG -e RST_N_FUNCTION
```

RAX3000M原厂信息如下（京东云百里相同）：  
```
Boot configuration bytes [PARTITION_CONFIG: 0x48]
Boot bus Conditions [BOOT_BUS_CONDITIONS: 0x00]
H/W reset function [RST_N_FUNCTION]: 0x01
```
接着合并的eMMC镜像mmcblk0p0-11.bin写入/dev/mmcblk0：  
```
dd if=mmcblk0p0-11.bin of=/dev/mmcblk0 bs=1M status=progress oflag=direct
```
最后查看分区表是否正确，是否显示12个分区，正确即可焊接回PCB板：  
注：如果是恢复op注意分区表是单分区的，会不同，检查无误就行。
```
fdisk -x /dev/mmcblk0
```
查看大致的eMMC寿命情况，寿命定义自行搜索：  
```
mmc extcsd read /dev/mmcblk0 | grep -e "Life Time" -e "EOL"
```
