# 编译配置

存放完整 `.config` 或精简 diffconfig，定义目标设备与软件包选择。工作流通过 `config_path` 选择文件，并在编译前运行 `make defconfig` 补全依赖。
