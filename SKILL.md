---
name: sandbox-env-setup
description: "Comprehensive cloud sandbox environment liberation system covering 8 core domains: Network, Filesystem, Process, Package Management, Browser/GUI, Dev Toolchain, MCP Integration, and Persistence. Use this skill when: starting in a new sandbox session, encountering any environment limitation, browser won't start, network is blocked, missing dependencies, Chrome DevTools MCP errors, 'cannot open shared object file' errors, or needing to establish a complete development environment from scratch. This skill provides proactive, predictive environment setup — not just reactive fixes. Trigger on: fix environment, sandbox setup, browser install, network blocked, missing deps, prepare workspace, environment check, setup toolchain, MCP error, chrome won't start, install dependencies."
compatibility: "Requires Node.js (v18+), npm, bash. Tested on Ubuntu 22.04/24.04 Linux x86_64 cloud containers."
---

# Sandbox Environment Liberation System

You are operating in a restricted cloud sandbox. This skill transforms a limited environment into a fully capable development workstation through systematic reconnaissance, diagnosis, and repair across 8 core domains.

## Architecture

```
sandbox-env-setup/
├── SKILL.md              ← This file (knowledge base)
├── scripts/
│   ├── full-recon.sh     ← Domain 1-8 reconnaissance
│   ├── diagnose.sh       ← Quick diagnosis (legacy)
│   ├── fetch-deps.js     ← Browser dep fetcher (legacy)
│   ├── fix-network.js    ← Network + browser repair
│   ├── setup-dev-toolchain.sh  ← Toolchain installation
│   ├── verify-env.sh     ← Full 8-domain verification
│   └── persist-config.sh ← Persistence configuration
└── references/
    ├── network-workarounds.md
    ├── capability-matrix.md
    └── troubleshooting.md
```

## Quick Start (3 Commands)

```bash
# Step 1: Reconnaissance — understand your environment
bash /workspace/sandbox-env-setup/scripts/full-recon.sh

# Step 2: Fix everything — network, browser, deps
node /workspace/sandbox-env-setup/scripts/fix-network.js

# Step 3: Verify — confirm full operational capability
bash /workspace/sandbox-env-setup/scripts/verify-env.sh
```

---

## The 8 Core Domains

### Domain 1: Network

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

---

### Domain 2: File System & Permissions

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

---

### Domain 3: Process & Resources

**What Works**:
- ✅ Background processes (detached with `nohup` + `disown`)
- ✅ `strace`/`ptrace` for debugging
- ✅ All `ulimit` settings unlimited
- ✅ Full `/proc` filesystem access

**What's Limited**:
- ⚠️ 2 CPU cores, 4GB memory (cgroup limits)
- ⚠️ No swap
- ❌ No `screen`/`tmux` (installable via apt)
- ❌ No Docker/Podman (kernel-level restriction)

**Installing screen/tmux**:
```bash
apt-get install -y screen tmux
```

**Running Long-Lived Processes**:
```bash
nohup your_command > /tmp/output.log 2>&1 &
disown
# Check status: cat /tmp/output.log
# Kill: kill $(pgrep -f your_command)
```

---

### Domain 4: Package Management

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

---

### Domain 5: Browser & GUI

**This is the #1 P0 issue in most sandboxes.** The browser is essential for Playwright MCP, web automation, and many development workflows.

**Complete Browser Setup** (automated by fix-network.js):

```bash
# Step 1: Install Playwright
npm install -g playwright

# Step 2: Install Chromium browser
npx playwright install chromium

# Step 3: Install missing system dependencies
# Option A: apt (preferred when available)
apt-get install -y libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgbm1 libasound2t64 libatk1.0-0 libatk-bridge2.0-0 \
  libatspi2.0-0 libcups2

# Option B: Node.js fetch fallback (when apt is blocked)
node /workspace/sandbox-env-setup/scripts/fix-network.js

# Step 4: Verify
node -e "const{chromium}=require('playwright');(async()=>{const b=await chromium.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});console.log('Browser OK:',await b.version());await b.close()})()"
```

**Common Missing Libraries** (Ubuntu 24.04):
```
libxkbcommon.so.0    → libxkbcommon0
libXcomposite.so.1   → libxcomposite1
libXdamage.so.1      → libxdamage1
libXfixes.so.3       → libxfixes3
libXrandr.so.2       → libxrandr2
libgbm.so.1          → libgbm1
libasound.so.2       → libasound2t64
libatk-1.0.so.0      → libatk1.0-0
libatk-bridge-2.0.so.0 → libatk-bridge2.0-0
libatspi.so.0        → libatspi2.0-0
libcups.so.2         → libcups2
```

**Chrome DevTools MCP**: Port 9222 is typically accessible. The Playwright MCP manages browser lifecycle automatically — do NOT manually launch Chrome with `--remote-debugging-port`.

**If MCP "Target closed" errors occur**: Fall back to Playwright Node.js API directly.

---

### Domain 6: Development Toolchain

**Pre-installed Runtimes** (via mise):
- Node.js v24.15.0, Python 3.14.4, Go 1.25.1, Java 25.0.2
- Ruby 3.4.4, PHP 8.5.6, Rust 1.92.0, Swift 6.2.4
- Elixir 1.18.3, Erlang OTP 27, Bun 1.2.14

**Pre-installed Build Tools**:
- make, cmake, gradle, maven, bazel

**Pre-installed Dev Tools**:
- git, SQLite3, SSH, gcc/g++, tar/gzip/zip

**Missing but Installable** (via setup-dev-toolchain.sh):
- screen/tmux: `apt-get install -y screen tmux`
- webpack/vite/esbuild: `npm install -g webpack vite esbuild`
- Python packages: `pip install --user virtualenv httpx requests`
- Go tools: `go install golang.org/x/tools/gopls@latest`

**Not Available** (kernel/container restrictions):
- Docker/Podman: No kernel access
- Cloud CLIs: Download binaries manually
- PostgreSQL/Redis: `apt-get install` if needed

---

### Domain 7: MCP & External Integration

**Available MCP Tools**:

| MCP | Capabilities | Key Use |
|-----|-------------|---------|
| Playwright | navigate, click, fill, screenshot, evaluate JS | Browser automation |
| Memory | create/read/search entities and relations | Persistent knowledge storage |
| Context7 | resolve-library-id, query-docs | Documentation lookup |
| WebFetch | Fetch URL content | Alternative network channel |
| Schedule | Create/update cron tasks | Automated recurring tasks |

**MCP Combination Patterns**:
- Playwright + Memory: Scrape web data → store in knowledge graph
- Context7 + Playwright: Look up docs → test code in browser
- WebFetch + Node.js: Fetch content → process with scripts
- Schedule + Memory: Periodic data collection → persistent storage

**Chrome DevTools Protocol**: Accessible on port 9222 when browser is running. Test with:
```bash
node -e "const http=require('http');http.get('http://127.0.0.1:9222/json/version',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))}).on('error',e=>console.log('FAIL'))"
```

---

### Domain 8: Persistence & Session Recovery

**What Persists Across Sessions**:
- ✅ Files in `/workspace` and `/root`
- ✅ Shell profiles (`.bashrc`, `.zshrc`, `.profile`)
- ✅ npm global packages
- ✅ mise-managed tool versions
- ✅ SSH keys
- ❓ `/tmp` may be cleared

**Maximizing Persistence** (automated by persist-config.sh):

```bash
# 1. Add environment setup to shell profiles
bash /workspace/sandbox-env-setup/scripts/persist-config.sh

# 2. In a new session, restore environment
source /usr/local/bin/sandbox-env-setup.sh

# 3. Quick re-setup if needed
bash /workspace/sandbox-env-setup/scripts/full-recon.sh  # Re-diagnose
node /workspace/sandbox-env-setup/scripts/fix-network.js  # Re-fix
```

**Session Recovery Checklist**:
1. Source environment setup script
2. Verify browser works (`npx playwright install chromium` if needed)
3. Re-install any missing apt packages
4. Restore environment variables from saved config

---

## Execution Workflow

### For New Sessions (Automatic)

```
1. full-recon.sh    → Understand current state
2. fix-network.js   → Fix browser + network
3. setup-dev-toolchain.sh → Install missing tools
4. persist-config.sh → Save configuration
5. verify-env.sh    → Confirm everything works
```

### For Specific Issues (Targeted)

| Problem | Solution |
|---------|----------|
| Browser won't start | `node scripts/fix-network.js` |
| apt fails | Check proxy: `cat /etc/apt/apt.conf.d/99proxy` |
| npm install hangs | `npm config set registry https://registry.npmmirror.com` |
| Missing library | `apt-get install -y <package>` or `node scripts/fix-network.js` |
| git clone fails | `git config --global http.proxy http://127.0.0.1:18080` |
| MCP "Target closed" | Use Playwright MCP (it manages browser lifecycle) |
| Disk full | `apt-get clean && npm cache clean --force` |
| Need a tool | `apt-get install` or `npm install -g` or download binary |

---

## Capability Matrix Summary

| Domain | Status | Key Blocker |
|--------|--------|-------------|
| Network | ✅ Mostly open | Direct TCP blocked (proxy required) |
| Filesystem | ✅ Full access | Limited disk space (~7.6GB) |
| Process | ✅ Mostly open | No Docker, limited CPU/memory |
| Packages | ✅ All managers work | None |
| Browser | ⚠️ Needs setup | Must install + fix deps |
| Toolchain | ✅ Rich pre-installed | Some tools need npm/apt |
| MCP | ✅ Full access | None |
| Persistence | ✅ Files persist | /tmp may be cleared |

---

## What This Skill Does NOT Do

- Install kernel modules or modify system security policies
- Bypass authentication or authorization systems
- Access resources outside the sandbox's actual permissions
- Modify other users' sessions or data
- Provide Docker-in-Docker capability (kernel restriction)

This skill only repairs and optimizes **toolchains within your existing permissions** — making the environment fully operational for development work.
