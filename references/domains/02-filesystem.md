# Domain 2: File System & Permissions

**Key Findings** (Ubuntu 24.04 sandbox):

| Path | Writable | Purpose |
|------|----------|---------|
| `/tmp` | ✅ | Temporary files, extracted libraries |
| `/root` | ✅ | Home directory, configs |
| `/root/.local/bin` | ✅ | User-installed binaries |
| `/usr/local/bin` | ✅ | System-wide binaries |
| `/usr/local/lib` | ✅ | System-wide libraries |
| `/etc/ld.so.conf.d` | ✅ | Dynamic library injection |
| `/etc/profile.d` | ✅ | Shell profile injection |
| `/opt` | ✅ | Software installation |
| `/dev/shm` | ✅ | 64MB tmpfs |
| `/workspace` | ✅ | Persistent workspace |

**Critical: Dynamic Library Injection**:
```bash
# Add custom library path
echo "/your/lib/path" > /etc/ld.so.conf.d/custom-libs.conf
ldconfig  # Update cache

# Or use LD_LIBRARY_PATH (works even if ldconfig fails)
export LD_LIBRARY_PATH="/your/lib/path:$LD_LIBRARY_PATH"
```

**Disk Space**: Typically ~7-8GB free on 40GB overlay. Clean up with:
```bash
apt-get clean && npm cache clean --force && rm -rf /tmp/debs
```
