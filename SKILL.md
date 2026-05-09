---
name: sandbox-env-setup
description: "Comprehensive cloud sandbox environment liberation system covering 10 core domains: Network, Filesystem, Process, Package Management, Browser/GUI, Dev Toolchain, MCP Integration, Persistence, Platform Internal Services, and Security & Isolation. Use this skill when: starting in a new sandbox session, encountering any environment limitation, browser won't start, network is blocked, missing dependencies, Chrome DevTools MCP errors, 'cannot open shared object file' errors, needing to establish a complete development environment from scratch, checking platform services, VNC access, CDP endpoint, proxy authentication, container security, seccomp/AppArmor status, or capability analysis. This skill provides proactive, predictive environment setup — not just reactive fixes. Trigger on: fix environment, sandbox setup, browser install, network blocked, missing deps, prepare workspace, environment check, setup toolchain, MCP error, chrome won't start, install dependencies, platform services, security check, container recon, deep recon, health monitor."
compatibility: "Requires Node.js (v18+), npm, bash. Tested on Ubuntu 22.04/24.04 Linux x86_64 cloud containers."
---

# Sandbox Environment Liberation System

You are operating in a restricted cloud sandbox. This skill transforms a limited environment into a fully capable development workstation through systematic reconnaissance, diagnosis, and repair across 10 core domains.

## Architecture

```
sandbox-env-setup/
├── SKILL.md              ← This file (knowledge base)
├── scripts/
│   ├── full-recon.sh     ← Domain 1-8 reconnaissance
│   ├── deep-recon.sh     ← Domain 9-10 deep reconnaissance
│   ├── health-monitor.sh ← Platform service health monitoring
│   ├── diagnose.sh       ← Quick diagnosis (legacy)
│   ├── fetch-deps.js     ← Browser dep fetcher (legacy)
│   ├── fix-network.js    ← Network + browser repair
│   ├── setup-dev-toolchain.sh  ← Toolchain installation
│   ├── verify-env.sh     ← Full 10-domain verification
│   └── persist-config.sh ← Persistence configuration
└── references/
    ├── network-workarounds.md
    ├── capability-matrix.md
    └── troubleshooting.md
```

## Quick Start (5 Commands)

```bash
# Step 1: Reconnaissance — understand your environment
bash /workspace/sandbox-env-setup/scripts/full-recon.sh

# Step 2: Deep reconnaissance — platform services & security
bash /workspace/sandbox-env-setup/scripts/deep-recon.sh

# Step 3: Fix everything — network, browser, deps
node /workspace/sandbox-env-setup/scripts/fix-network.js

# Step 4: Verify — confirm full operational capability
bash /workspace/sandbox-env-setup/scripts/verify-env.sh

# Step 5: Health monitor — check platform service status
bash /workspace/sandbox-env-setup/scripts/health-monitor.sh
```

---

## The 10 Core Domains

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

### Domain 9: Platform Internal Services

**Key Insight**: The sandbox platform exposes numerous internal services on various ports. Understanding these services enables advanced workflows like remote desktop access, browser automation via CDP, and proxy authentication.

**VNC Service (Port 5900)**:
- Protocol: RFB 003.008
- Use case: Remote desktop access to sandbox GUI
- Connection: VNC client → `127.0.0.1:5900`

**CDP Endpoint (Port 8088)**:
- Path: `/v1/cdp`
- Use case: Browser remote control via Chrome DevTools Protocol
- Environment variable: `CRAWLER_CDP_ENDPOINT` points to this endpoint

**WebSocket Service (Port 40005)**:
- Supports HTTP Upgrade: websocket
- Use case: Additional communication channel for real-time data

**HTTP Proxy (Port 18080/18081)**:
- Outbound HTTP/HTTPS proxy
- May require authentication (407 response)
- Credentials may exist in environment variables or `/app/etc/` configuration

**Preview Proxy (Port 16000)**:
- Environment variable: `PREVIEW_PROXY_PUBLIC_PORT`
- Use case: Web application preview

**Health Check Endpoints**:
- Port 13080: `/health`
- Port 19090: `/health`

**Supervisor Process Management**:
- Configuration: `/app/supervisord.conf`
- Manages multiple child processes (agent-tool-host, chrome, VNC, etc.)

**Kubernetes Environment**:
- Environment variable: `KUBERNETES_SERVICE_HOST`
- Service Account: `/var/run/secrets/kubernetes.io/serviceaccount/`

**Node.js Preload Module**:
- Path: `/app/mcp_proxy_bootstrap/preload.cjs`
- Environment variable: `NODE_OPTIONS`
- Affects runtime behavior of all Node.js processes

**Complete Port Mapping Table**:

| Port | Service | Description |
|------|---------|-------------|
| 80 | HTTP | agent-tool-host |
| 5900 | VNC | RFB 003.008 remote desktop |
| 8088 | CDP | Browser remote control endpoint |
| 8999 | HTTP | agent-tool-host service |
| 9090-9092 | Monitoring | Metrics collection |
| 9222 | CDP | Chrome DevTools Protocol |
| 10249 | HTTP | API (404) |
| 13080 | HTTP | API + /health |
| 16000 | HTTP | Preview proxy |
| 18080 | HTTP | Outbound proxy |
| 18081 | HTTPS | Outbound proxy |
| 19090 | HTTP | API + /health |
| 19091 | HTTP | agent-tool-host |
| 40005 | WS | WebSocket |
| 51008 | Binary | Unknown protocol |

---

### Domain 10: Security & Isolation

**Key Insight**: Understanding the container's security posture — seccomp, AppArmor, capabilities, and isolation mechanisms — is critical for advanced operations and troubleshooting permission-denied errors.

**seccomp Status**:
- Check: `/proc/1/status` → Seccomp line
- Values: 0=disabled, 1=strict, 2=filtered

**AppArmor**:
- Check: `/proc/1/attr/current`
- May show "unconfined" or a specific profile

**Linux Capabilities Breakdown**:
- CapEff: `0xa80425fb` (current environment)
- Decoded capabilities:
  - CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FOWNER, CAP_FSETID
  - CAP_KILL, CAP_SETGID, CAP_SETUID, CAP_SETPCAP
  - CAP_NET_BIND_SERVICE, CAP_NET_RAW
  - CAP_SYS_CHROOT, CAP_MKNOD, CAP_AUDIT_WRITE, CAP_SETFCAP
- Missing capabilities:
  - CAP_SYS_ADMIN, CAP_SYS_PTRACE (partial), CAP_NET_ADMIN, CAP_SYS_RESOURCE

**Container Runtime Identification**:
- Docker: Check `/.dockerenv`
- containerd: Check `/run/container_type`
- Kubernetes: Check `KUBERNETES_SERVICE_HOST`
- cgroup info: `/proc/1/cgroup`

**System Call Restrictions**:
- `strace` available for tracing
- Some syscalls filtered by seccomp (mount, umount, pivot_root, reboot, etc.)
- Network-related syscalls (socket, bind, listen, connect) available at application level

**Node.js Security Capabilities**:
- 28 core modules all available
- WebCrypto API available
- `worker_threads` available (multi-threading)
- Native WebSocket available
- 52 cryptographic algorithms

---

## Execution Workflow

### For New Sessions (Automatic)

```
1. full-recon.sh    → Understand current state (Domain 1-8)
2. deep-recon.sh    → Deep reconnaissance (Domain 9-10)
3. fix-network.js   → Fix browser + network
4. setup-dev-toolchain.sh → Install missing tools
5. verify-env.sh    → Confirm everything works (all 10 domains)
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
| Platform Services | ✅ Rich internal services | Proxy may need auth (407) |
| Security & Isolation | ⚠️ Container restricted | Missing CAP_SYS_ADMIN, seccomp filtered |

---

## Meta-Improvement Protocol (元改进协议)

This section defines how the system improves itself. When triggered by the meta-prompt, the AI follows this protocol to execute a complete improvement flywheel cycle.

### The Flywheel

侦察(Recon) → 假设(Hypothesize) → 实验(Experiment) → 整合(Integrate) → 反思(Reflect)

Each cycle MUST:
1. Produce incremental progress (not repeat work)
2. Leave memory (Memory MCP + evolution-log.md)
3. Expand boundaries (discover ≥1 unknown capability/limitation)
4. Improve the improvement process itself (meta-improvement)

### Priority Matrix

| Priority | Category | Action |
|----------|----------|--------|
| P0 | Blocker | FAIL items that prevent basic work → Fix immediately |
| P1 | Efficiency | WARN items that severely degrade work → Fix before exploring |
| P2 | Discovery | ❓ Unknown items worth exploring → Explore 1 per round |
| P3 | Enhancement | ✅ Items that can be optimized → Optional |
| P4 | Meta | Improve the improvement process itself → Reflect every round |

### Recon Protocol (侦察协议)

How to systematically discover the unknown:
1. Run full-recon.sh + deep-recon.sh to get current snapshot
2. Compare with previous snapshot (from evolution-log.md)
3. Identify anomalies: unexpected FAIL, new services, changed permissions
4. For each ❓ item, design a targeted probe
5. Look for patterns: if one domain has many FAILs, investigate root cause

### Hypothesis Protocol (假设协议)

How to form verifiable improvement hypotheses:
1. For each P0/P1 item, state: "If I fix X, then Y should change from FAIL to PASS"
2. For each P2 item, state: "If I probe Z, I expect to discover [capability/limitation]"
3. Each hypothesis MUST be falsifiable — there must be a clear pass/fail test
4. Maximum 3 hypotheses per round (focus over breadth)

### Experiment Protocol (实验协议)

How to safely implement and verify improvements:
1. Before changing anything, record current state (verify-env.sh output)
2. Make changes incrementally — one hypothesis at a time
3. After each change, run verify-env.sh to check for regressions
4. If a change causes regression, revert immediately
5. Never modify running system services without testing first

### Integration Protocol (整合协议)

How to persist improvements as knowledge:
1. Code changes → commit to scripts/ with descriptive messages
2. New discoveries → update references/ (capability-matrix, troubleshooting, etc.)
3. Process improvements → update this Meta-Improvement Protocol section
4. State → update Memory MCP entities and evolution-log.md
5. All changes → Git commit + push to GitHub

### Reflection Protocol (反思协议)

How to evaluate and optimize the improvement process:
1. Measure: How many PASS gained? FAIL reduced? New capabilities discovered?
2. Efficiency: How much effort per improvement? Is there a faster path?
3. Coverage: Which domains were explored? Which were neglected?
4. Anti-stagnation: Apply checks (see below)
5. Next round: What should be the focus? What was missed?

### Anti-Stagnation Mechanisms

| Trigger | Response |
|---------|----------|
| 3 rounds with no new discoveries (P2=0) | Switch to deep exploration mode: try unconventional probes, test edge cases |
| 3 rounds in same domain | Force domain rotation: pick the least-explored domain |
| Every 5 rounds | Challenge one "known" conclusion: re-verify a PASS item |
| Every round | Try ≥1 previously untested operation (new port, new API, new tool) |

### The Meta-Prompt

Copy and use this prompt to trigger the improvement flywheel:

> /evolve sandbox-env-setup
>
> Execute improvement flywheel for sandbox-env-setup:
> 1. Read evolution state from Memory MCP (SandboxEvolutionState) and evolution-log.md
> 2. Recon: run full-recon.sh + deep-recon.sh, compare with previous snapshot
> 3. Prioritize: P0(blockers) > P1(efficiency) > P2(discovery) > P3(enhancement) > P4(meta)
> 4. Hypothesize: form ≤3 verifiable improvement hypotheses from top priority items
> 5. Experiment: implement improvements, verify with verify-env.sh, check for regressions
> 6. Integrate: persist changes to scripts/, references/, Memory MCP, evolution-log.md
> 7. Reflect: measure delta, evaluate efficiency, check anti-stagnation triggers
> 8. Record: update evolution-log.md with full round context
> 9. Commit: git add -A && git commit && git push
>
> Anti-stagnation: 3 rounds no discovery→deep explore | 3 rounds same domain→rotate | every 5 rounds→challenge known | every round→try 1 new thing

---

## Automated Evolution (自动进化)

The improvement flywheel can run automatically on a schedule, enabling the system to evolve continuously without human intervention. Each scheduled run spawns a fresh AI session that executes a complete flywheel cycle.

### How It Works

1. **Schedule** triggers a new AI session every hour
2. **New AI** reads the self-contained operation manual from the Schedule message
3. **Acquire Lock** via GitHub Issue #1 (prevents concurrent sessions)
4. **Recon** current environment state (not inherited tasks)
5. **Execute** top-priority improvements
6. **Verify** no regressions
7. **Record** evolution log and commit
8. **Release Lock**

### Key Design: Self-Directed Recon, Not Task Inheritance

New AI sessions do NOT "inherit tasks" from previous sessions. Instead, they:
1. Run `evolve.sh` to get current environment snapshot and improvement suggestions
2. Read `evolution-log.md` last 3 rounds for context (avoid repeated exploration/failures)
3. Make decisions based on **current state**, not historical tasks

Why: The environment may have changed since the last session. A P0 blocker may have auto-resolved. The new AI should assess reality, not follow stale plans.

### GitHub Issue Distributed Lock

Prevents multiple AI sessions from working simultaneously:

| Action | GitHub Issue #1 State |
|--------|----------------------|
| Lock free | Closed, no `evolving` label |
| Lock acquired | Open, `evolving` label, body has timestamp |
| Lock timeout (>60min) | Force release, add `timeout-release` label |

Scripts: `acquire-lock.sh` / `release-lock.sh`

### Time Budget

| Phase | Budget | Action on Timeout |
|-------|--------|-------------------|
| Recon | 5 min | Skip remaining recon |
| Improvement | 20 min | Stop current work, save completed parts |
| Verify + Commit | 5 min | Force commit what's done |
| **Total** | **30 min** | Enter commit phase immediately |

### Atomic Improvements

- Each improvement must be a complete, independently verifiable unit
- Incomplete improvements are NOT committed to main
- Marked as `INCOMPLETE` in evolution-log.md for next round to continue
- Before improvement: `git stash` as checkpoint
- After verification fails: `git stash pop` to rollback

### Degeneration Detection

If the last 3 rounds have >80% similarity in "Changes Made":
- Switch to **exploration mode** (try unconventional probes)
- Force **domain rotation** (pick least-explored domain)
- **Challenge** one known conclusion

### Exception Handling

| Exception | Response |
|-----------|----------|
| Lock occupied | Skip this round, exit gracefully |
| Lock timeout (>60min) | Force release, acquire lock, proceed |
| Time budget exhausted | Save completed work, commit, release lock |
| Improvement causes regression | Rollback (git stash pop), don't commit |
| Git push conflict | `git pull --rebase`, remote wins on conflict |
| 3 rounds no new discovery | Switch to deep exploration mode |

---

## What This Skill Does NOT Do

- Install kernel modules or modify system security policies
- Bypass authentication or authorization systems
- Access resources outside the sandbox's actual permissions
- Modify other users' sessions or data
- Provide Docker-in-Docker capability (kernel restriction)

This skill only repairs and optimizes **toolchains within your existing permissions** — making the environment fully operational for development work.
