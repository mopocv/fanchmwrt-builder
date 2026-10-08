# FanchmWrt 在线编译

使用 GitHub Actions 构建 [FanchmWrt](https://github.com/fanchmwrt/fanchmwrt)，支持自定义软件包、系统默认设置和固件发布。

## 使用

1. 按需设置 [GitHub Actions Secrets](docs/secrets.md)。
2. 打开 **Actions → Build FanchmWrt → Run workflow**。
3. 选择源码分支和编译配置，默认使用 `fanchmwrt-25.12.4` 与 `configs/x86_64.config`。
4. 构建完成后下载 Artifacts；开启 `publish_release` 可发布到 Releases。

`build_name` 设置下载包名称，`hostname` 设置系统主机名。固件版本号跟随源码，避免影响软件中心的版本识别。

## 自定义

| 路径 | 用途 |
| --- | --- |
| `configs/` | 目标设备和软件包配置 |
| `custom/feeds.conf.default` | 基础 feeds 及固定提交 |
| `custom/feeds.conf.append` | 追加第三方 feeds |
| `custom/required-packages.txt` | 每次构建默认启用的软件包清单 |
| `custom/packages/` | 自定义软件包源码 |
| `custom/files/` | 固件文件覆盖 |
| `custom/patches/` | 源码补丁 |
| `scripts/` | 应用定制配置与生成首次启动设置 |

添加软件包来源后，在编译配置中启用对应的 `CONFIG_PACKAGE_包名=y`。密码和私有地址使用 Secrets，不写入仓库。

默认包清单包含 Git、SSH 和基础命令工具，并启用 `fanchmwrt-packages` 提交 `75c3c55e1d3d26ac0fbaf391c394b57c7b04285e` 中的全部 17 个应用包、16 个中文语言包，包括作者的独立无线设置、流量统计和新版特征库页面。普通模式的网络设置额外提供标准防火墙管理入口。

无线默认配置使用主机名作为 SSID，密码从 `FANCHMWRT_WIFI_PASSWORD` Secret 注入。R86S N305 的 Intel 无线驱动同时启用 AX201 和 AX101 固件包，以覆盖设备实际请求的固件文件；该网卡默认使用 2.4 GHz、HT20，一个网卡仅提供一个 AP。

要增删默认包，直接编辑 `custom/required-packages.txt`，每行一个包名；构建会在 `make defconfig` 后检查这些包是否启用，缺失时在编译前失败。
