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

## IPv6

IPv6 resolution may work even when IPv4 direct connections don't. Test with:
```bash
node -e "const dns=require('dns');dns.lookup('google.com',{family:6},(e,a)=>console.log(e?'FAIL':'OK:'+a))"
```
