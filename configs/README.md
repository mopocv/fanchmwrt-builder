# Build configurations

Upload OpenWrt `.config` files into this directory. A descriptive filename such
as `x86_64.config` is easier to manage than several files all named `.config`.

To generate a portable configuration from a local FanchmWrt checkout:

```bash
make menuconfig
./scripts/diffconfig.sh > x86_64.config
```

The workflow accepts either a complete `.config` or `diffconfig` output and
runs `make defconfig` before compiling.
