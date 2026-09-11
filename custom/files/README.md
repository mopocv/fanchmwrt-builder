# Root filesystem overlay

Files placed here are copied into the firmware root filesystem. The directory
layout must start at `/`; for example:

```text
custom/files/etc/banner
custom/files/etc/uci-defaults/90-my-settings
```

Use an executable `/etc/uci-defaults/` script for settings that should be
applied once on the first boot.
