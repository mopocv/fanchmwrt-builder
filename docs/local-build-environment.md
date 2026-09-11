# 上次本地编译环境与迁移记录

依据：旧 outputs 中的环境说明、实际助手脚本及 x86-64 构建信息（2026-08-10）。

- 主机：Intel Mac，macOS 13.7.8；Colima Linux，2 CPU、约 4 GB 内存、80 GB 虚拟磁盘。
- 构建镜像：`ghcr.io/openwrt/buildbot/buildworker-v3.8.0:v9`。
- Mac 源码置于大小写敏感 APFS 稀疏映像，编译在 Docker 原生 Linux 卷 `fanchmwrt-build` 中进行。
- 源码分支：`fanchmwrt-25.12.4`；当前参考 checkout 是 `12af57cfd23ee1ed80e9cce063f8b2e225a9428e`。
- 实际产物版本记录：`r32933-4ccb782af7`。与参考 checkout 不同；未确认该后缀对应的完整提交，不能声称逐字节复现旧固件。Actions 仍按所选分支或标签获取源码。
- `configs/x86_64.config` 来自产物 `config.buildinfo`，保留 x86/64 generic、256 MiB 内核分区、2048 MiB 根分区、Docker、Lucky、Nikki、R86S 应用中心等选项。
- `custom/feeds.conf.default` 来自产物 `feeds.buildinfo`，固定全部九个 feed 的实际提交；追加 feed 时不要重复已有名称。
- 旧内网 IP、广播地址已从公开配置移除。设置 LAN Secret 后由首次启动脚本覆盖 LAN 地址；没有设置时保留上游默认地址。
- 旧说明称 `make -j2`，实际助手执行 `make -j1 V=s`；迁移助手保留实际行为。
- 旧记录称 prereq / defconfig 已成功，但本次未重新运行完整 Linux 编译。

## 继续使用已有本地环境

` scripts/local-env.zsh ` 是原助手的可迁移版本，使用环境变量指定旧 `outputs` 目录；不会把旧磁盘映像或固件复制进 Git。

```sh
export FANCHMWRT_LOCAL_OUTPUTS_DIR="/absolute/path/to/previous/outputs"
zsh scripts/local-env.zsh status
zsh scripts/local-env.zsh menuconfig
zsh scripts/local-env.zsh build
zsh scripts/local-env.zsh export
```

需要已有 Colima、Docker、稀疏映像以及构建卷。它管理旧环境，不会自动使用本仓库的 configs/custom 内容；Actions 才会自动应用这些配置。`sync` 会按旧助手行为镜像同步源码到构建卷。

## GitHub Actions Secrets

在仓库 Settings → Secrets and variables → Actions → New repository secret 中添加：

| Secret | 内容 | 未设置时 |
| --- | --- | --- |
| `FANCHMWRT_LAN_IP` | 旧配置中的 LAN IPv4 地址，可在原始 config.buildinfo 的 CONFIG_TARGET_PREINIT_IP 项查看 | 保留上游 LAN 地址 |
| `FANCHMWRT_ROOT_PASSWORD` | 明文 root 密码，构建时自动生成随机盐 SHA-512 crypt 哈希 | 未设置两种密码 Secret 时保留上游行为 |
| `FANCHMWRT_ROOT_PASSWORD_HASH` | 可选 SHA-512 crypt 密码哈希，可用 `openssl passwd -6` 交互生成 | 保留上游密码行为 |

两种密码 Secret 只设置其中一种；同时设置会终止构建，避免密码来源歧义。明文密码不能包含换行，通过标准输入传给 OpenSSL，不进入命令参数或固件；固件只写入哈希。

Secrets 仅通过环境变量交给默认配置步骤，不写入仓库或公开的构建配置。未在旧构建记录中发现账号、Token 或密码，因此没有推测或自动创建这些值。本次只接好引用，没有将 Secret 值写入 GitHub。

注意：写入固件的地址和密码哈希仍可从固件中提取；Secrets 保护仓库和日志，不会加密最终固件。分发含私有设置的固件前请确认接收范围。

官方说明：https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets

## 固件名称与软件中心版本识别

已将旧配置的 `CONFIG_VERSION_NUMBER="260810"` 改为空，使用源码 `include/version.mk` 的默认版本（当前参考分支为 `25.12.4`）。日期不是软件仓库的版本号，不要把构建日期或自定义名称填到此项。

软件中心固定提交中的 `get_arch_and_version()` 读取 `/etc/openwrt_release` 的 `DISTRIB_ARCH` 和 `DISTRIB_RELEASE`，再由 `fetch_server_list()` 请求软件列表。旧设置会把 `260810` 发送为 version，造成版本不匹配的可能；本次修正这一配置错误。

- 下载压缩包名称：Actions 的 `build_name`，默认 `fanchmwrt-r86s`，可自由调整；运行编号会自动追加。
- 系统主机名：Actions 的 `hostname`。
- 发行名称 `CONFIG_VERSION_DIST="FanchmWrt"`、产品名 `CONFIG_VERSION_PRODUCT="r86s"` 和 GRUB 标题保留。
- 版本号 `CONFIG_VERSION_NUMBER` 保持空，跟随源码默认值；不要用它给固件起名。

源码依据：[软件中心控制器（固定提交）](https://github.com/fanchmwrt/fanchmwrt-packages/blob/fdfa9a6f8e02ab9ad10e2961271ba9a4fa872458/luci-app-fwx-app-center/luasrc/controller/fwx_app_center.lua#L989)。服务端还接收 `/etc/fwx_release` 中的发布信息和设备型号；本次未连接路由器或验证服务端列表，因此不保证仅修正版本即可恢复全部插件。安装阶段另有 `/etc/fwx_version` 的兼容性检查，不应伪造版本或绕过它。

此修改对重新编译的固件生效，已刷入设备不会自动改变。若新固件仍报错，应核对设备上的 `/etc/openwrt_release`、`/etc/fwx_release`、`/etc/fwx_version` 和软件中心响应。

## 温度监控插件

新增 `temp_status` feed，来源为 https://github.com/gSpotx2f/luci-app-temp-status ，固定提交 `7c47517c1cd3d1ccf52eda9237279a45d5884e34`。源码声明版本 `0.8.1-r1`，并包含俄语翻译资源。

已选中 `luci-app-temp-status` 和 `luci-i18n-temp-status-ru`；依赖 `ucode`、`ucode-mod-fs` 由包定义引入。已核对源码版本和翻译文件，尚未执行完整固件编译。
