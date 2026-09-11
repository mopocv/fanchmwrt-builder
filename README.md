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
| `custom/packages/` | 自定义软件包源码 |
| `custom/files/` | 固件文件覆盖 |
| `custom/patches/` | 源码补丁 |
| `scripts/` | 应用定制配置与生成首次启动设置 |

添加软件包来源后，在编译配置中启用对应的 `CONFIG_PACKAGE_包名=y`。密码和私有地址使用 Secrets，不写入仓库。
