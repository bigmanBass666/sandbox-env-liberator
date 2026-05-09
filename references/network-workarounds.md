# Network Workarounds Reference

## Network Architecture in Cloud Sandboxes

Cloud sandboxes typically use a proxy-based network architecture:
- **Inbound**: No direct inbound connections (except via platform-provided URLs)
- **Outbound**: Routed through an HTTP proxy (typically `127.0.0.1:18080`)
- **DNS**: Internal resolver (e.g., `172.30.1.10`)
- **Direct TCP**: Often blocked or heavily filtered

## Network Channels (Ranked by Reliability)

| Channel | Reliability | Speed | Use Case |
|---------|------------|-------|----------|
| Node.js `fetch()` | ⭐⭐⭐⭐⭐ | Fast | Primary download channel |
| Python `urllib` | ⭐⭐⭐⭐ | Fast | Alternative when Node.js unavailable |
| `curl` | ⭐⭐⭐⭐ | Fast | Works when proxy is configured |
| `wget` | ⭐⭐⭐⭐ | Fast | Works when proxy is configured |
| `apt-get` | ⭐⭐⭐⭐ | Fast | System packages (respects proxy) |
| Go `net/http` | ⭐⭐⭐ | Medium | Works but slower startup |
| Playwright `page.goto()` | ⭐⭐⭐ | Slow | Last resort, browser as proxy |
| Direct TCP sockets | ⭐ | N/A | Usually blocked |
| `git clone` | ⭐⭐⭐⭐ | Medium | Works via proxy |

## Proxy Configuration

### Environment Variables
```bash
export http_proxy=http://127.0.0.1:18080
export https_proxy=http://127.0.0.1:18080
export no_proxy=localhost,127.0.0.1,.svc,.cluster.local,::1
```

### npm Proxy
```bash
npm config set proxy http://127.0.0.1:18080
npm config set https-proxy http://127.0.0.1:18080
```

### git Proxy
```bash
git config --global http.proxy http://127.0.0.1:18080
git config --global https.proxy http://127.0.0.1:18080
```

### apt Proxy
```bash
echo 'Acquire::http::Proxy "http://127.0.0.1:18080";' > /etc/apt/apt.conf.d/99proxy
echo 'Acquire::https::Proxy "http://127.0.0.1:18080";' >> /etc/apt/apt.conf.d/99proxy
```

## Mirror Configuration

### npm Registry
```bash
npm config set registry https://registry.npmmirror.com
```

### pip Mirror
```bash
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
```

### Go Proxy
```bash
go env -w GOPROXY=https://goproxy.cn,direct
```

## Downloading Files When CLI Networking Fails

### Method 1: Node.js fetch (Recommended)
```javascript
const fs = require('fs');
async function download(url, dest) {
    const resp = await fetch(url, { signal: AbortSignal.timeout(60000) });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const buf = Buffer.from(await resp.arrayBuffer());
    fs.writeFileSync(dest, buf);
    return buf.length;
}
```

### Method 2: Python urllib
```python
import urllib.request
urllib.request.urlretrieve('https://example.com/file', '/tmp/file')
```

### Method 3: Browser as Proxy (Playwright)
```javascript
const { chromium } = require('playwright');
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
const resp = await page.goto('https://example.com/file');
const content = await resp.body();
require('fs').writeFileSync('/tmp/file', content);
await browser.close();
```

## Port Availability

Common ports that may be locally listening:
- **80**: HTTP (platform services)
- **9090**: Monitoring/metrics
- **9222**: Chrome DevTools Protocol

Outbound connectivity is typically proxy-only. Direct TCP connections to external hosts usually timeout.

## WebSocket 通道

- 端口40005提供WebSocket服务
- Node.js原生WebSocket可用
- 可作为额外通信通道

## 代理认证处理

代理可能返回407 Proxy Authentication Required。

凭据来源:
- 环境变量 (PROXY_USER/PROXY_PASS)
- 代理URL中的user:pass
- /app/etc/配置文件

自动配置: fix-network.js的`detectAndHandleProxyAuth()`函数

手动配置:
```bash
export http_proxy=http://user:pass@127.0.0.1:18080
export https_proxy=http://user:pass@127.0.0.1:18081
```

## 5通道自动降级下载

1. curl (首选CLI工具)
2. wget (备选CLI工具)
3. Node.js fetch() (最可靠的编程通道)
4. Python urllib (备选编程通道)
5. Playwright page.goto() (浏览器作为代理，最后手段)

使用方法:
```javascript
const { downloadWithFallback, downloadWithRetry } = require('/workspace/sandbox-env-setup/scripts/fix-network');
await downloadWithRetry('https://example.com/file', '/tmp/file');
```

## IPv6

IPv6 resolution may work even when IPv4 direct connections don't. Test with:
```bash
node -e "const dns=require('dns');dns.lookup('google.com',{family:6},(e,a)=>console.log(e?'FAIL':'OK:'+a))"
```
