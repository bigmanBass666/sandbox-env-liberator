# Domain 1: Network

**Key Insight**: Cloud sandboxes route traffic through an HTTP proxy (typically `127.0.0.1:18080`). Direct TCP connections are usually blocked, but HTTP/HTTPS through the proxy works.

**Network Channels (by reliability)**:

| Channel | Reliability | When to Use |
|---------|------------|-------------|
| Node.js `fetch()` | ⭐⭐⭐⭐⭐ | Primary download channel |
| Python `urllib` | ⭐⭐⭐⭐ | Alternative when Node.js unavailable |
| `curl`/`wget` | ⭐⭐⭐⭐ | Works when proxy is configured |
| `apt-get` | ⭐⭐⭐⭐ | System packages (respects proxy) |
| `git clone` | ⭐⭐⭐⭐ | Version control |
| Go `net/http` | ⭐⭐⭐ | Works but slower startup |
| Playwright `page.goto()` | ⭐⭐⭐ | Last resort: browser as proxy |
| Direct TCP sockets | ⭐ | Usually blocked |

**Proxy Configuration** (auto-detected and configured by fix-network.js):

```bash
# Environment (usually pre-set)
export http_proxy=http://127.0.0.1:18080
export https_proxy=http://127.0.0.1:18080
export no_proxy=localhost,127.0.0.1,.svc,.cluster.local,::1

# npm
npm config set proxy http://127.0.0.1:18080
npm config set https-proxy http://127.0.0.1:18080

# git
git config --global http.proxy http://127.0.0.1:18080
git config --global https.proxy http://127.0.0.1:18080

# apt
echo 'Acquire::http::Proxy "http://127.0.0.1:18080";' > /etc/apt/apt.conf.d/99proxy
```

**Mirror Configuration** (for faster downloads):

```bash
# npm
npm config set registry https://registry.npmmirror.com

# pip
mkdir -p ~/.pip && cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# Go
go env -w GOPROXY=https://goproxy.cn,direct
```

**When ALL networking fails**: Use `WebFetch` MCP tool or Playwright MCP to fetch content through the platform's network channel.

## Workarounds Reference

### Network Architecture in Cloud Sandboxes

Cloud sandboxes typically use a proxy-based network architecture:
- **Inbound**: No direct inbound connections (except via platform-provided URLs)
- **Outbound**: Routed through an HTTP proxy (typically `127.0.0.1:18080`)
- **DNS**: Internal resolver (e.g., `172.30.1.10`)
- **Direct TCP**: Often blocked or heavily filtered

### Network Channels (Ranked by Reliability)

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

### Proxy Configuration

#### Environment Variables
```bash
export http_proxy=http://127.0.0.1:18080
export https_proxy=http://127.0.0.1:18080
export no_proxy=localhost,127.0.0.1,.svc,.cluster.local,::1
```

#### npm Proxy
```bash
npm config set proxy http://127.0.0.1:18080
npm config set https-proxy http://127.0.0.1:18080
```

#### git Proxy
```bash
git config --global http.proxy http://127.0.0.1:18080
git config --global https.proxy http://127.0.0.1:18080
```

#### apt Proxy
```bash
echo 'Acquire::http::Proxy "http://127.0.0.1:18080";' > /etc/apt/apt.conf.d/99proxy
echo 'Acquire::https::Proxy "http://127.0.0.1:18080";' >> /etc/apt/apt.conf.d/99proxy
```

### Mirror Configuration

#### npm Registry
```bash
npm config set registry https://registry.npmmirror.com
```

#### pip Mirror
```bash
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
```

#### Go Proxy
```bash
go env -w GOPROXY=https://goproxy.cn,direct
```

### Downloading Files When CLI Networking Fails

#### Method 1: Node.js fetch (Recommended)
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

#### Method 2: Python urllib
```python
import urllib.request
urllib.request.urlretrieve('https://example.com/file', '/tmp/file')
```

#### Method 3: Browser as Proxy (Playwright)
```javascript
const { chromium } = require('playwright');
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
const resp = await page.goto('https://example.com/file');
const content = await resp.body();
require('fs').writeFileSync('/tmp/file', content);
await browser.close();
```

### Port Availability

Common ports that may be locally listening:
- **80**: HTTP (platform services)
- **9090**: Monitoring/metrics
- **9222**: Chrome DevTools Protocol

Outbound connectivity is typically proxy-only. Direct TCP connections to external hosts usually timeout.

### WebSocket 通道

- 端口40005提供WebSocket服务
- Node.js原生WebSocket可用
- 可作为额外通信通道

### 代理认证处理

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

### 5通道自动降级下载

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

### CDP Browser Connection (浏览器直连绕过)

**Problem**: Downloading Chromium binary (~170MB) fails in restricted networks or takes too long.

**Solution**: The sandbox platform runs Chrome 147+ with CDP already enabled on port 9222. Connect to it directly instead of downloading a local Chromium.

```javascript
const { connectCDPBrowser } = require('/workspace/sandbox-env-setup/scripts/fix-network');

// Method 1: Use the helper function (recommended)
const browser = await connectCDPBrowser();
if (browser) {
    const page = browser.contexts()[0].pages()[0] || await browser.contexts()[0].newPage();
    await page.goto('https://example.com');
}

// Method 2: Use Playwright API directly
const { chromium } = require('playwright');
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
```

**How it works**:
1. Probes `http://127.0.0.1:9222/json/version` to confirm CDP is available
2. Parses browser version info (Browser, Protocol-Version)
3. Calls `chromium.connectOverCDP()` to attach to running Chrome
4. Returns browser instance (or `null` if unavailable)

**When to use this workaround**:
- `npx playwright install chromium` fails or hangs
- Disk space is limited (~170MB savings)
- Need instant browser access (no download wait)
- Network is too slow for large downloads

**Service context**: The CDP browser is managed by **browser_ctrl** on port 9090 (Prometheus metrics, 3 workers). Do not close the browser — other tools may depend on it.

### IPv6

IPv6 resolution may work even when IPv4 direct connections don't. Test with:
```bash
node -e "const dns=require('dns');dns.lookup('google.com',{family:6},(e,a)=>console.log(e?'FAIL':'OK:'+a))"
```
