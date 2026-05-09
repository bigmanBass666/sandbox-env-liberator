# Troubleshooting Reference

## Browser Issues

### "error while loading shared libraries"
**Symptom**: Chrome/Chromium fails to start with missing .so files
**Root Cause**: Browser binary exists but system lacks required shared libraries
**Solution**:
```bash
# Method 1: apt install (preferred when network works)
apt-get install -y libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgbm1 libasound2t64 libatk1.0-0 libatk-bridge2.0-0 \
  libatspi2.0-0 libcups2

# Method 2: Node.js fetch fallback (when apt is blocked)
node /workspace/sandbox-env-setup/scripts/fix-network.js
```

### Chrome DevTools MCP "Target closed"
**Symptom**: MCP tools like `mcp_Playwright_*` fail with "Target closed"
**Root Cause**: Chrome process crashed or wasn't launched with correct flags
**Solution**:
1. Ensure browser deps are installed first
2. Use Playwright MCP directly (it manages browser lifecycle)
3. Don't manually launch Chrome with --remote-debugging-port

### Playwright "Browser not found"
**Symptom**: `Error: Executable doesn't exist at ...`
**Solution**:
```bash
npx playwright install chromium
```

## Network Issues

### apt-get fails with "Could not connect"
**Root Cause**: Proxy not configured for apt
**Solution**:
```bash
echo 'Acquire::http::Proxy "http://127.0.0.1:18080";' > /etc/apt/apt.conf.d/99proxy
echo 'Acquire::https::Proxy "http://127.0.0.1:18080";' >> /etc/apt/apt.conf.d/99proxy
```

### npm install hangs
**Root Cause**: npm not using proxy or registry is slow
**Solution**:
```bash
npm config set proxy http://127.0.0.1:18080
npm config set https-proxy http://127.0.0.1:18080
npm config set registry https://registry.npmmirror.com
```

### git clone fails
**Root Cause**: git not configured for proxy
**Solution**:
```bash
git config --global http.proxy http://127.0.0.1:18080
git config --global https.proxy http://127.0.0.1:18080
```

### All CLI networking fails
**Root Cause**: Proxy not set in environment
**Solution**:
```bash
export http_proxy=http://127.0.0.1:18080
export https_proxy=http://127.0.0.1:18080
# Then use Node.js fetch as fallback:
node -e "fetch('https://example.com').then(r=>r.text()).then(t=>console.log(t))"
```

## File System Issues

### ldconfig fails with "Permission denied"
**Root Cause**: Running in restricted container
**Solution**: Use `LD_LIBRARY_PATH` instead:
```bash
export LD_LIBRARY_PATH="/tmp/extracted_libs/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
```

### /dev/shm too small for Chrome
**Symptom**: Chrome crashes with "shared memory" errors
**Solution**:
```bash
# Use /tmp instead
mkdir -p /tmp/shm
chmod 1777 /tmp/shm
export CHROMIUM_FLAGS="--disable-dev-shm-usage"
```

### Disk space running low
**Solution**:
```bash
# Clean up common space wasters
rm -rf /tmp/debs /tmp/extracted_libs
apt-get clean
npm cache clean --force
go clean -cache
```

## Process Issues

### Background process killed immediately
**Root Cause**: cgroup or container policy
**Solution**: Use `nohup` and `disown`:
```bash
nohup your_command &
disown
```

### Cannot install Docker
**Root Cause**: Kernel-level restriction in sandbox
**Solution**: Use alternatives:
- Download static binaries for tools
- Use `chroot` for isolation
- Connect to remote Docker hosts via `DOCKER_HOST`

## Package Management Issues

### pip install fails with permission error
**Solution**:
```bash
pip install --user package_name
# Or install to custom directory:
pip install --target /root/.local/lib/python3.x/site-packages package_name
```

### Go module download fails
**Solution**:
```bash
go env -w GOPROXY=https://goproxy.cn,direct
go env -w GONOSUMCHECK=*
```

### Cargo build fails (no C compiler)
**Solution**:
```bash
apt-get install -y build-essential
```

## VNC连接问题

**症状**: 无法连接VNC
**检查**:
```bash
node -e "const net=require('net');const s=net.createConnection({host:'127.0.0.1',port:5900,timeout:2000},()=>{console.log('VNC OK');s.destroy()});s.on('error',e=>console.log('VNC FAIL:',e.message))"
```
**修复**: VNC服务由Supervisor管理，检查 `cat /app/supervisord.conf`

## CDP端点问题

**症状**: CRAWLER_CDP_ENDPOINT不可达
**检查**:
```bash
curl -s http://127.0.0.1:8088/v1/cdp
```
**修复**: CDP端点由agent-tool-host管理，检查进程 `ps aux | grep agent-tool-host`

## 代理认证问题

**症状**: curl/wget返回407
**修复**: 运行 `node /workspace/sandbox-env-setup/scripts/fix-network.js` 自动检测和配置
**手动**: 检查环境变量和/app/etc/下的配置文件

## 磁盘空间不足

**症状**: 磁盘使用率>85%
**修复**:
```bash
apt-get clean && npm cache clean --force && rm -rf /tmp/debs /tmp/extracted_libs
```

## 健康监控

**运行**:
```bash
bash /workspace/sandbox-env-setup/scripts/health-monitor.sh
```
**查看历史**:
```bash
cat /tmp/sandbox-health/history.log
```

## Quick Diagnostic Commands

```bash
# Full environment check
bash /workspace/sandbox-env-setup/scripts/full-recon.sh

# Quick network test
node -e "fetch('https://httpbin.org/ip').then(r=>r.json()).then(d=>console.log('OK:',d.origin)).catch(e=>console.log('FAIL:',e.message))"

# Quick browser test
node -e "const{chromium}=require('playwright');(async()=>{const b=await chromium.launch({headless:true});console.log('Browser OK');await b.close()})()"

# Full verification
bash /workspace/sandbox-env-setup/scripts/verify-env.sh
```
