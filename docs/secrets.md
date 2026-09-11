# GitHub Actions Secrets

在仓库 **Settings → Secrets and variables → Actions → New repository secret** 中按需添加：

| 名称 | 用途 |
| --- | --- |
| `FANCHMWRT_LAN_IP` | 默认 LAN IPv4 地址 |
| `FANCHMWRT_ROOT_PASSWORD` | 明文 root 密码，构建时自动生成带随机盐的 SHA-512 crypt 哈希 |
| `FANCHMWRT_ROOT_PASSWORD_HASH` | 已生成的 SHA-512 crypt 哈希，替代明文密码方式 |

两种密码 Secret 只设置一个，同时设置会终止构建。明文密码按原样填写，不加 Shell 转义符，不能包含换行。未设置的项目保留上游默认行为。

保存后重新运行工作流，设置在新固件首次启动时应用。明文密码不写入固件；固件中的地址和密码哈希仍可被提取。
