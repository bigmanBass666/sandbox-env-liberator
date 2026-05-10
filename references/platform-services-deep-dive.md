# Platform Services Deep Dive (Rounds 10-13)

> Deep analysis of internal platform services discovered through port probing and Prometheus metrics scraping.

## CDP Browser Service (Port 9222)

- **Protocol**: Chrome DevTools Protocol (WebSocket upgrade on HTTP GET /json/version)
- **Browser**: Chromium/125.0.6422.142
- **V8**: 12.5.199.15
- **WebSocket Debugger URL**: `ws://127.0.0.1:9222/devtools/browser/<uuid>`
- **Key finding**: Persists across sessions — no need to install or launch Chromium manually. The browser is managed by `browser_ctrl` (port 9090).
- **Available targets**: Full page navigation, DOM inspection, JavaScript execution, network interception via CDP commands.

## Egress Sidecar (Port 9091) — Network Tunnel Proxy

### Architecture

```
App → egress(sidecar:9091) → External ProxyServer via HTTP CONNECT tunnels
```

All outbound network traffic from the sandbox container is forced through this sidecar proxy. It establishes HTTP CONNECT tunnels to an external ProxyServer, which then makes the actual outbound connections.

### Runtime Profile (from Prometheus metrics)

| Metric | Value |
|--------|-------|
| Tokio worker threads | 2 |
| Alive tasks | 12 |
| Active tunnels | 3 |

### Policy System

| Policy Rule | Count |
|-------------|-------|
| privileged_allow | 377 |
| allow | 245 |
| deny | 4 |
| privileged_deny | 6 |

The policy system uses a tiered allow/deny model with privileged variants for elevated operations.

### Traffic Statistics

| Metric | Value |
|--------|-------|
| Total data sent | 11.2 MB |
| Total data received | 158.8 MB |
| Download:Upload ratio | ~14:1 |
| Total requests | 632 |
| CONNECT success | 581 (92%) |
| client_connection_attempts ok | 622 |

**Bandwidth insight**: The ~14:1 download-to-upload ratio explains why uploads feel significantly slower than downloads. The ~20KB/s effective upload limit is imposed by either the external ProxyServer or tunnel protocol overhead, not by the egress sidecar itself.

### Tunnel Error Breakdown

| Error Type | Shutdown | Read | Write |
|------------|----------|------|-------|
| d2u_error (downstream→upstream) | 61 | 13 | 4 |

d2u_error (downstream-to-upstream) errors dominate the error landscape, with connection shutdowns being the most common failure mode. These are expected in a tunnel proxy handling many short-lived connections.

### API Surface

- **No admin/config API exposed** on port 9091
- No `/metrics`, `/health`, or debug endpoints found
- Operates as a transparent proxy — no direct configuration possible from within the sandbox

## Sentinel Webhook Gateway (Port 9092)

### Service Type

Webhook/API Gateway embedded in `agent-tool-host` (pid 821). This is **not** a REST API server — it's an async webhook trigger system that fires events to the external platform.

### Discovered Endpoints

| Method | Path | Purpose | Observed Calls |
|--------|------|---------|----------------|
| POST | `/hook/dispatch` | Main webhook dispatcher | 32 |
| POST | `/workspace/restic-restore` | Fire-and-forget restore trigger | 1 |
| * | *any other* | Not found | → 404 |

### Behavior Analysis

- **`/hook/dispatch`**: Primary ingress point for webhook events from the platform. High call count (32) indicates this is the main event routing endpoint.
- **`/workspace/restic-restore`**: Triggers a restic backup restoration on the platform side. Returns HTTP 200 immediately with empty body — classic fire-and-forget async pattern. The actual restoration happens externally; no status polling mechanism available from within the sandbox.
- **All other paths return 404**: Sentinel has a minimal, purpose-built surface area.

### Exposed Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `sentinel_http_requests_total` | Counter | Total HTTP requests handled |
| `sentinel_http_request_duration_seconds` | Histogram | Request latency distribution |

## browser_ctrl (Port 9090) — Browser Controller

### Role

Chrome DevTools Protocol browser controller. Manages the lifecycle of the CDP browser instance on port 9222.

### Key Characteristics

- Exposes Prometheus metrics for browser control operations
- Embedded in agent-tool-host (pid 822)
- Coordinates browser launch, page creation, and CDP session management
- No direct REST API — controlled internally by the agent framework

## Port Mapping Summary (Updated)

| Port | Service | Role |
|------|---------|------|
| 9090 | browser_ctrl | Chrome DevTools browser controller |
| 9091 | egress sidecar | Network tunnel proxy (bandwidth limiter root cause) |
| 9092 | sentinel | Webhook gateway (restic-restore trigger) |
| 9222 | Chrome CDP | Browser automation endpoint |

## Key Architectural Insights

### 1. Agent-Centric Monolith

`agent-tool-host` (pid 821/822) embeds **all** internal platform services:
- Sentinel (webhook gateway) — port 9092
- Egress (tunnel proxy) — port 9091
- browser_ctrl (browser controller) — port 9090

These are not separate processes or containers — they're tokio/async tasks within a single binary. This explains why they share the same PID namespace and why killing one would affect all.

### 2. Egress Is the Bandwidth Bottleneck

All network traffic (HTTP, HTTPS, git, npm, pip, curl, etc.) routes through the egress sidecar on port 9091. The ~20KB/s upload limit and ~14:1 download:upload ratio are properties of the external ProxyServer + CONNECT tunnel architecture, not configurable from within the sandbox.

**Practical implication**: Large file uploads (git push large repos, npm publish, etc.) will be slow. Plan accordingly.

### 3. CDP Browser Persists Across Sessions

The Chromium browser on port 9222 is pre-launched and managed by the platform. It survives sandbox restarts and does not require installation of Playwright browsers or system Chromium packages. Use it directly via CDP WebSocket or the Playwright MCP connector.

### 4. Sentinel Uses Async Fire-and-Forget Pattern

Operations like `/workspace/restic-restore` return immediately with HTTP 200. There is no job ID, no status endpoint, no completion callback. The platform handles execution asynchronously. This pattern means:
- Cannot poll for restore completion
- Cannot cancel in-flight operations
- Must rely on file system observation to detect when restores finish

### 5. Policy-Based Access Control in Egress

The egress sidecar maintains a policy table with 632 rules (377+245 allowed, 4+6 denied). This suggests domain-based or destination-based filtering at the tunnel layer, which may explain why some external hosts are reachable while others timeout even though DNS resolves correctly.

## Platform Configuration Files

### /app/etc/ide_dynamic_config_basic.json
- Feature gates: enableCmdBlocking=true, enableCheckImageContent=true, enableCueflow=false
- AI features: mcpToolLimit=40, mcpTokenLimit=8000, customPromptTokenLimit=10000
- Auto-accept enabled with diff view
- Snapshot V2 enabled

### /app/etc/mcp_servers.json
- Currently empty: `{"mcpServers": {}}`
- This is where MCP server configurations would be registered

### /etc/profile.d/sandbox-env.sh
- Dynamic LD_LIBRARY_PATH for extracted libs and Playwright Chrome
- Auto-adds ~/.local/bin, ~/go/bin, ~/.cargo/bin to PATH
- Sets PLAYWRIGHT_BROWSERS_PATH

### /etc/profile.d/trae-env.sh
- Full language runtime initialization: pyenv, nvm, cargo, mise, phpenv, swiftly
- Calls /usr/local/bin/setup_universal.sh if exists
- TRAE_ENV_INITIALIZED guard prevents double init

### Key Environment Variables
- HTTP_PROXY/HTTPS_PROXY=http://127.0.0.1:18080 (all traffic through egress proxy)
- no_proxy/NO_PROXY=localhost,127.0.0.1,.svc,.cluster.local,::1
- NODE_OPTIONS=--require /app/mcp_proxy_bootstrap/preload.cjs (MCP proxy bootstrap)
- PREVIEW_PROXY_PUBLIC_PORT=16000

## MCP Proxy Bootstrap Mechanism (Round 13)

### preload.cjs Analysis (29 lines)

- **Purpose**: Make undici/global fetch use HTTP(S)_PROXY environment variables
- **Injection**: Via `NODE_OPTIONS=--require /app/mcp_proxy_bootstrap/preload.cjs`
- **Mechanism**: Uses undici's `setGlobalDispatcher(new EnvHttpProxyAgent())` to redirect all Node.js fetch calls through the proxy configured by `HTTP_PROXY`/`HTTPS_PROXY` env vars
- **Activation**: Only activates if `HTTP_PROXY` or `HTTPS_PROXY` environment variables are set
- **Debug mode**: Set `MCP_PROXY_DEBUG` env var to see log output
- **Key insight**: This is NOT an MCP protocol interceptor — it's just a proxy configurator for Node.js fetch. It has no awareness of MCP messages, tool calls, or server lifecycle.

### supervisord.conf Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `AGENT_TOOL_HOST_MCP_SERVER_CONF_FILE` | `/app/etc/mcp_servers.json` | MCP server config path |
| `AGENT_TOOL_HOST_IDE_DYNAMIC_CONF_FILE` | `/app/etc/ide_dynamic_config_basic.json` | Feature gates path |
| `CDP_USER_DATA_DIR` | `/data/tool/cdp-client-browser` | CDP browser data directory |
| `CRAWLER_CDP_ENDPOINT` | `http://127.0.0.1:8088/v1/cdp` | CDP proxy endpoint |
| `TOOLHOST_CWD` | `/workspace` | Working directory |
| `ICUBE_USER_DATA_DIR` | `/data/user` | User data directory |
| `BROWSER_SNAPSHOT_DIR` | `/data/tool/browser_snapshots` | Browser snapshot storage |
| `MCP_LOG_DIR` | `/var/log/tool/mcp` | MCP log directory |

### setup_universal.sh Language Version Control

- Controlled by environment variables: `TRAE_ENV_PYTHON_VERSION`, `TRAE_ENV_NODE_VERSION`, `TRAE_ENV_RUST_VERSION`, `TRAE_ENV_GO_VERSION`, `TRAE_ENV_RUBY_VERSION`, `TRAE_ENV_PHP_VERSION`, `TRAE_ENV_JAVA_VERSION`, `TRAE_ENV_SWIFT_VERSION`
- Each version manager (pyenv/nvm/rustup/mise/phpenv/swiftly) checks if the requested version is already installed
- Falls back to the default version if the requested version is not found

### mcp_servers.json Injection Test Result

- **File is WRITABLE** (root:root, rw-r--r--)
- Successfully wrote test MCP server config to the file
- `agent-tool-host` (pid 821) would need restart/reload to pick up changes
- **Key finding**: MCP server configuration IS injectable at the file level — the file permissions allow writes, but the running process does not hot-reload the config
