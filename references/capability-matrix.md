# Capability Matrix

Based on reconnaissance of Ubuntu 24.04 cloud sandbox environment.

## Legend
- ✅ Available
- ⚠️ Available with constraints
- ❌ Not available
- ❓ Unknown / needs testing

## Domain 1: Network

| Capability | Status | Notes |
|-----------|--------|-------|
| DNS resolution | ✅ | System resolver works |
| curl HTTP/HTTPS | ✅ | Via proxy (127.0.0.1:18080) |
| wget HTTP/HTTPS | ✅ | Via proxy |
| Node.js fetch() | ✅ | Primary escape hatch |
| Python urllib | ✅ | Works with SSL context |
| Go net/http | ✅ | Works |
| apt-get | ✅ | Via proxy |
| git clone/push | ✅ | Via proxy |
| npm install | ✅ | Via proxy |
| pip install | ✅ | Via proxy |
| Direct TCP outbound | ❌ | Timeout on all tested ports |
| IPv6 | ✅ | Resolution works |
| WebSocket | ❓ | Not tested |

## Domain 2: File System & Permissions

| Capability | Status | Notes |
|-----------|--------|-------|
| /tmp writable | ✅ | Standard tmp |
| /root writable | ✅ | Full home access |
| /usr/local/bin writable | ✅ | Can install system-wide binaries |
| /usr/local/lib writable | ✅ | Can install system-wide libraries |
| /etc/ld.so.conf.d writable | ✅ | Dynamic library injection possible |
| /etc/profile.d writable | ✅ | Shell profile injection possible |
| /opt writable | ✅ | Software installation |
| /dev/shm writable | ✅ | 64MB tmpfs |
| ldconfig | ✅ | Library cache update works |
| Symlinks | ✅ | Full support |
| Hardlinks | ✅ | Full support |
| Disk space | ⚠️ | ~7.6GB free on 40GB overlay |
| Container capabilities | ⚠️ | Limited (0xa80425fb) |
| /proc filesystem | ✅ | Fully accessible |

## Domain 3: Process & Resources

| Capability | Status | Notes |
|-----------|--------|-------|
| Background processes | ✅ | Detached processes survive |
| nohup | ✅ | Available |
| screen | ❌ | Not installed (apt install available) |
| tmux | ❌ | Not installed (apt install available) |
| strace/ptrace | ✅ | Full process tracing |
| Docker | ❌ | Not available |
| Podman | ❌ | Not available |
| CPU | ⚠️ | 2 cores, cgroup limited (200000/100000) |
| Memory | ⚠️ | 4GB cgroup limit, ~3.8GB physical |
| ulimits | ✅ | All unlimited |
| Swap | ❌ | No swap configured |

## Domain 4: Package Management

| Capability | Status | Notes |
|-----------|--------|-------|
| apt-get install | ✅ | Full access |
| dpkg | ✅ | Package extraction |
| pip install | ✅ | With --target support |
| npm install | ✅ | Global and local |
| npx -y | ✅ | Remote package execution |
| Go modules | ✅ | go install works |
| Cargo | ✅ | cargo install works |
| Binary download+execute | ✅ | Via Node.js fetch |
| Source compilation (C/C++) | ✅ | gcc/g++/make/cmake available |

## Domain 5: Browser & GUI

| Capability | Status | Notes |
|-----------|--------|-------|
| Playwright Chromium | ⚠️ | Requires install + deps fix |
| Chrome Headless Shell | ⚠️ | Requires install + deps fix |
| Google Chrome | ❌ | Not pre-installed |
| Firefox | ❌ | Not available |
| Playwright Node module | ⚠️ | Requires npm install |
| xvfb/VNC | ❌ | Not installed |
| VS Code Server | ❌ | Not detected |
| Chrome DevTools Protocol | ✅ | Port 9222 accessible |

## Domain 6: Dev Toolchain

| Capability | Status | Notes |
|-----------|--------|-------|
| git | ✅ | v2.43.0, network accessible |
| SQLite3 | ✅ | Functional |
| PostgreSQL | ❌ | Not installed |
| Redis | ❌ | Not installed |
| Node.js | ✅ | v24.15.0 |
| Python | ✅ | v3.14.4 |
| Go | ✅ | v1.25.1 |
| Java | ✅ | OpenJDK 25.0.2 |
| Ruby | ✅ | v3.4.4 |
| PHP | ✅ | v8.5.6-dev |
| Rust | ✅ | v1.92.0 |
| Swift | ✅ | v6.2.4 |
| Elixir | ✅ | v1.18.3 |
| Erlang | ✅ | OTP 27 |
| Bun | ✅ | v1.2.14 |
| make | ✅ | GNU Make 4.3 |
| cmake | ✅ | v3.28.3 |
| gradle | ✅ | v8.14.4 |
| maven | ✅ | v3.9.10 |
| bazel | ✅ | Available |
| webpack/vite/esbuild | ❌ | Not installed (npm install available) |
| Cloud CLIs | ❌ | None installed |
| Container tools | ❌ | None installed |
| SSH client | ✅ | Available |

## Domain 7: MCP & External Integration

| Capability | Status | Notes |
|-----------|--------|-------|
| Playwright MCP | ✅ | Browser automation via SOLO |
| Memory MCP | ✅ | Knowledge graph storage |
| Context7 MCP | ✅ | Documentation lookup |
| WebFetch | ✅ | URL content fetching |
| Schedule | ✅ | Cron-based task scheduling |
| CDP (port 9222) | ✅ | Chrome DevTools Protocol |

## Domain 8: Persistence

| Capability | Status | Notes |
|-----------|--------|-------|
| File persistence | ✅ | /workspace and /root persist |
| Shell profiles | ✅ | .bashrc, .zshrc, .profile exist |
| npm global packages | ✅ | 7 packages installed |
| mise tool versions | ✅ | Multiple runtimes managed |
| Environment variables | ⚠️ | Persist in shell profiles only |
| /tmp persistence | ❓ | May be cleared between sessions |

## Priority Bottlenecks

### P0 (Blocks basic work)
1. **Browser not installed** → Fix: `npm install -g playwright && npx playwright install chromium`
2. **Browser missing deps** → Fix: `apt-get install -y libxkbcommon0 libxcomposite1 ...` or `node fix-network.js`

### P1 (Severely degrades efficiency)
3. **No screen/tmux** → Fix: `apt-get install -y screen tmux`
4. **No frontend build tools** → Fix: `npm install -g webpack vite esbuild`
5. **No cloud CLIs** → Fix: Download binaries via Node.js fetch

### P2 (Specific scenarios)
6. **No Docker** → No fix (kernel-level restriction)
7. **No databases** → Fix: `apt-get install -y postgresql redis-server`
8. **Limited /dev/shm** → Workaround: use /tmp instead

### P3 (Nice to have)
9. **No VNC** → Fix: `apt-get install -y xvfb x11vnc novnc`
10. **No VS Code Server** → Fix: Download and install code-server
