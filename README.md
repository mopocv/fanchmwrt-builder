# FanchmWrt 在线编译

该仓库使用 GitHub Actions 编译
[`fanchmwrt/fanchmwrt`](https://github.com/fanchmwrt/fanchmwrt)，不保存完整源码，
每次构建时按指定分支或标签拉取源码。目前默认分支为
`fanchmwrt-25.12.4`，构建环境使用 Ubuntu 22.04。

## 第一次构建

1. 在本地 FanchmWrt 源码目录运行 `make menuconfig` 完成选择。
2. 推荐运行 `./scripts/diffconfig.sh > x86_64.config` 得到精简配置；也可直接使用完整 `.config`。
3. 打开本仓库的 `configs` 目录，选择 **Add file → Upload files**，上传配置并提交。
4. 打开 **Actions → Build FanchmWrt → Run workflow**。
5. 将 `config_path` 填为 `configs/x86_64.config`，按需设置源码分支、主机名和 LAN IP，然后运行。
6. 构建成功后，从该次运行的 **Artifacts** 下载压缩包；若启用 `publish_release`，也会创建长期保留的 Release。

> GitHub Actions 的 `workflow_dispatch` 页面不支持文件类型输入，因此需要先把本地配置上传到 `configs/`，再填写仓库内路径。

## 自定义插件

有三种方式，按维护成本从低到高排列：

- 第三方插件仓库：在 `custom/feeds.conf.append` 中添加标准 OpenWrt feed，再在 `.config` 中选择对应包。
- 单个本地插件：把包含 OpenWrt `Makefile` 的插件目录放入 `custom/packages/`。
- 必须修改源码的插件或功能：把变更保存为 `custom/patches/*.patch`，不要每次构建时临时手改源码。

新增 feed 或包后，要重新生成 `.config`，确保相应的 `CONFIG_PACKAGE_xxx=y` 已被选择。

## 修改默认配置

- 软件包、内核和目标设备选择：放在 `configs/*.config`。
- 默认主机名、LAN IP：运行工作流时填写输入项；脚本会生成首次启动时执行的 UCI 配置。
- 固件内固定文件：按根目录结构放入 `custom/files/`。
- 对上游源码的修改：优先保存为补丁放入 `custom/patches/`。
- 更复杂、需要条件判断的改动：写入 `scripts/customize-defaults.sh` 或新建脚本并由工作流调用。

应当把重复修改写成脚本或补丁。这样更新 `source_ref` 后仍可重放所有变更，构建结果也能追溯。普通配置选择无需写 `sed` 脚本，保存在 `.config` 即可；默认系统参数优先使用 UCI defaults，不建议直接替换整份 `/etc/config/*`。

## 目录说明

| 路径 | 用途 |
| --- | --- |
| `.github/workflows/build-fanchmwrt.yml` | 在线构建、缓存、产物上传与 Release |
| `configs/` | 本地上传的完整 `.config` 或 diffconfig |
| `custom/feeds.conf.append` | 第三方 feeds |
| `custom/packages/` | 本地 OpenWrt 插件源码 |
| `custom/files/` | 固件根文件系统覆盖内容 |
| `custom/patches/` | 对 FanchmWrt 源码的可重复补丁 |
| `scripts/` | 源码准备和默认 UCI 配置脚本 |

## 注意事项

- 不要把账号密码、Token、Wi-Fi 密码等敏感信息提交到公开仓库；需要时使用 GitHub Actions Secrets。
- 建议固定第三方 feed 的分支或提交，避免同一 `.config` 在不同日期得到不一致结果。
- 大型目标可能超过 GitHub 托管 Runner 的 6 小时限制或可用磁盘；此时可切换到 Linux 自托管 Runner。
- 重新发布固件时请保留 FanchmWrt 与相关开源组件的版权及许可证信息。
