# Domain 4: Package Management

**All major package managers work**:

| Manager | Status | Notes |
|---------|--------|-------|
| `apt-get install` | ✅ | Via proxy, full access |
| `dpkg` | ✅ | Package extraction |
| `pip install` | ✅ | With `--user` or `--target` |
| `npm install` | ✅ | Global and local |
| `npx -y` | ✅ | Execute remote packages |
| `go install` | ✅ | Go modules |
| `cargo install` | ✅ | Rust crates |
| Binary download | ✅ | Via Node.js fetch |
| Source compile | ✅ | gcc/g++/make/cmake available |

**Installing to User Directory** (when system install fails):
```bash
# pip
pip install --user package_name
pip install --target /root/.local/lib/python3.x/site-packages package_name

# npm
npm install -g package_name  # Usually works
npm install --prefix /root/.local package_name  # Fallback

# Go
GOBIN=/root/.local/bin go install tool@latest

# Cargo
cargo install --root /root/.local tool
```

**Downloading & Running Binaries**:
```javascript
// Node.js fetch for binary download
const fs = require('fs');
const { execSync } = require('child_process');

async function installBinary(url, dest, chmod = true) {
    const resp = await fetch(url, { signal: AbortSignal.timeout(60000) });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const buf = Buffer.from(await resp.arrayBuffer());
    fs.writeFileSync(dest, buf);
    if (chmod) execSync(`chmod +x "${dest}"`);
    return dest;
}
```
