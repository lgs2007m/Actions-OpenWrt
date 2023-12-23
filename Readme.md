# 借助 GitHub Actions 的 OpenWrt 在线自动编译.

yml脚本默认使用mtwifi-cfg.config配置文件，配置文件含luci-app-dockerman。

在运行workflow时可选是否使用mtwifi-cfg和是否编译luci-app-dockerman，默认不使用mtwifi-cfg，默认编译luci-app-dockerman。

hanwckf大佬开发的mtwifi-cfg无线界面和mtk-sdk luci-app-mtk无线界面区别，详见大佬的博客
[cmi.hanwckf.top](https://cmi.hanwckf.top/p/immortalwrt-mt798x/#mtwifi%E6%97%A0%E7%BA%BF%E9%85%8D%E7%BD%AE%E5%B7%A5%E5%85%B7%E8%AF%B4%E6%98%8E)

## hanwckf大佬mt798x闭源仓库

- [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x).

## 237大佬mt798x闭源仓库

- [padavanonly/immortalwrt-mt798x](https://github.com/padavanonly/immortalwrt-mt798x).

## hanwckf大佬的mt798x uboot仓库
- [hanwckf/bl-mt798x](https://github.com/hanwckf/bl-mt798x).

### 感谢P3TERX的Actions-OpenWrt
- [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
[Read the details in my blog (in Chinese) | 中文教程](https://p3terx.com/archives/build-openwrt-with-github-actions.html)
