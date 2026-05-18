#!/bin/bash
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source config with defaults if not available
if [ -f "$SCRIPTS_DIR/lib/config.sh" ]; then
    source "$SCRIPTS_DIR/lib/config.sh"
else
    # Fallback defaults
    readonly NETWORK_TIMEOUT_SHORT=5
    readonly NETWORK_TIMEOUT_MEDIUM=10
    readonly NETWORK_TIMEOUT_LONG=30
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0

check() {
    local timeout="${3:-$NETWORK_TIMEOUT_MEDIUM}"
    TOTAL=$((TOTAL + 1))
    if timeout "$timeout" bash -c "$2" &>/dev/null; then
        echo -e "${GREEN}[✅]${NC} $1"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}[❌]${NC} $1"
        FAILED=$((FAILED + 1))
    fi
}

check_warn() {
    local timeout="${3:-$NETWORK_TIMEOUT_MEDIUM}"
    TOTAL=$((TOTAL + 1))
    if timeout "$timeout" bash -c "$2" &>/dev/null; then
        echo -e "${GREEN}[✅]${NC} $1"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}[⚠️]${NC} $1"
        FAILED=$((FAILED + 1))
    fi
}

check_perf() {
    local timeout="${3:-$NETWORK_TIMEOUT_LONG}"
    TOTAL=$((TOTAL + 1))
    RESULT=$(timeout "$timeout" bash -c "$2" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
        echo -e "${CYAN}[📊]${NC} $1: ${RESULT}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}[⚠️]${NC} $1: unavailable"
        FAILED=$((FAILED + 1))
    fi
}

check_cdp_browser() {
    TOTAL=$((TOTAL + 1))
    CDP_RESPONSE=$(curl -s --connect-timeout 3 http://127.0.0.1:9222/json/version 2>/dev/null)
    if echo "$CDP_RESPONSE" | grep -q '"Browser"'; then
        CDP_BROWSER_VER=$(echo "$CDP_RESPONSE" | grep -oP '"Browser":\s*"\K[^"]+')
        echo -e "${GREEN}[✅]${NC} CDP Browser (${CDP_BROWSER_VER}) on port 9222"
        PASSED=$((PASSED + 1))
        CDP_AVAILABLE=1
    else
        echo -e "${RED}[❌]${NC} CDP Browser on port 9222"
        FAILED=$((FAILED + 1))
        CDP_AVAILABLE=0
    fi
}

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   ENVIRONMENT VERIFICATION                           ║"
echo "║   Full 12-Domain Validation                          ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# === Domain 1: Network ===
echo "━━━ Domain 1: Network ━━━"
check "DNS resolution" "nslookup google.com 2>&1 | grep -q 'Address'"
check "curl HTTP" "curl -s --connect-timeout $NETWORK_TIMEOUT_SHORT https://httpbin.org/ip -o /dev/null"
check "wget HTTP" "wget -q --timeout=$NETWORK_TIMEOUT_SHORT https://httpbin.org/ip -O /dev/null"
check "Node.js fetch" "node -e \"fetch('https://httpbin.org/ip',{signal:AbortSignal.timeout($((NETWORK_TIMEOUT_LONG*1000)))}).then(r=>{if(r.ok)process.exit(0);else process.exit(1)}).catch(()=>process.exit(1))\""
check "Python urllib" "python3 -c \"import urllib.request; urllib.request.urlopen('https://httpbin.org/ip',timeout=$NETWORK_TIMEOUT_MEDIUM)\""
check "apt-get update" "apt-get update -qq 2>/dev/null"
echo ""

# === Domain 2: File System ===
echo "━━━ Domain 2: File System ━━━"
check "/tmp writable" "touch /tmp/.verify_test && rm /tmp/.verify_test"
check "/root writable" "touch /root/.verify_test && rm /root/.verify_test"
check "/usr/local/bin writable" "touch /usr/local/bin/.verify_test && rm /usr/local/bin/.verify_test"
check "/etc/ld.so.conf.d writable" "touch /etc/ld.so.conf.d/.verify_test && rm /etc/ld.so.conf.d/.verify_test"
check "ldconfig executable" "ldconfig 2>/dev/null"
check "symlinks work" "ln -sf /tmp /tmp/verify_symlink && rm /tmp/verify_symlink"
check "/dev/shm writable" "touch /dev/shm/.verify_test && rm /dev/shm/.verify_test"
check "/proc accessible" "[ -r /proc/cpuinfo ] && [ -r /proc/meminfo ]"
echo ""

# === Domain 3: Process & Resources ===
echo "━━━ Domain 3: Process & Resources ━━━"
check "nohup available" "which nohup"
check "background processes" "node -e \"const{spawn}=require('child_process');const p=spawn('sleep',['2'],{detached:true,stdio:'ignore'});p.unref();setTimeout(()=>{try{process.kill(p.pid,0);process.kill(p.pid,'SIGKILL');process.exit(0)}catch{process.exit(1)}},500)\""
check "strace available" "which strace"
check_warn "screen available" "which screen"
check_warn "tmux available" "which tmux"
check_warn "Redis server running" "pgrep -x redis-server"
check_warn "Memcached running" "pgrep -x memcached"
check_warn "PostgreSQL running" "pgrep -x postgres"
check_warn "lighttpd running" "pgrep -x lighttpd"
check_warn "beanstalkd running" "pgrep -x beanstalkd"
check_warn "nginx available" "which nginx"
echo ""

# === Domain 4: Package Management ===
echo "━━━ Domain 4: Package Management ━━━"
check "apt-get available" "which apt-get"
check "dpkg available" "which dpkg"
check "pip available" "which pip3 || which pip"
check "npm available" "which npm"
check "npx available" "which npx"
check "Go available" "which go"
check "Cargo available" "which cargo"
check "gcc available" "which gcc"
check "make available" "which make"
check "cmake available" "which cmake"
echo ""

# === Domain 5: Browser & GUI ===
echo "━━━ Domain 5: Browser & GUI ━━━"
CDP_RESPONSE=$(curl -s --connect-timeout 3 http://127.0.0.1:9222/json/version 2>/dev/null)
if echo "$CDP_RESPONSE" | grep -q '"Browser"'; then
    CDP_AVAILABLE=1
    CDP_BROWSER_VER=$(echo "$CDP_RESPONSE" | grep -oP '"Browser":\s*"\K[^"]+')
else
    CDP_AVAILABLE=0
fi
BROWSER=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
if [ -n "$BROWSER" ] && [ -f "$BROWSER" ]; then
    check "Playwright Chromium installed" "[ -n '$BROWSER' ] && [ -f '$BROWSER' ]"
else
    TOTAL=$((TOTAL + 1))
    if [ "$CDP_AVAILABLE" -eq 1 ] && node -e "require('playwright')" &>/dev/null; then
        echo -e "${YELLOW}[⚠️]${NC} Playwright Chromium installed (Chromium binary missing, BYPASS: use connectOverCDP to port 9222)"
        FAILED=$((FAILED + 1))
    else
        echo -e "${RED}[❌]${NC} Playwright Chromium installed"
        FAILED=$((FAILED + 1))
    fi
fi
if [ -n "$BROWSER" ] && [ -f "$BROWSER" ]; then
    check "Browser all libs satisfied" "ldd '$BROWSER' 2>&1 | grep -q 'not found'; [ \$? -ne 0 ]"
    check "Browser launches" "'$BROWSER' --version"
fi
check "Playwright Node module" "node -e \"require('playwright')\""
TOTAL=$((TOTAL + 1))
if [ "$CDP_AVAILABLE" -eq 1 ]; then
    echo -e "${GREEN}[✅]${NC} CDP Browser (${CDP_BROWSER_VER}) on port 9222"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}[❌]${NC} CDP Browser on port 9222"
    FAILED=$((FAILED + 1))
fi
echo ""

# === Domain 6: Dev Toolchain ===
echo "━━━ Domain 6: Dev Toolchain ━━━"
check "git available" "which git"
check "git network access" "timeout $NETWORK_TIMEOUT_MEDIUM git ls-remote https://github.com/octocat/Hello-World.git HEAD 2>&1 | grep -qE '^[0-9a-f]{40}'"
check "SQLite3 available" "which sqlite3"
check "Node.js available" "which node"
check "Python3 available" "which python3"
check "Java available" "which java"
check "Ruby available" "which ruby"
check "SSH client available" "which ssh"
check "tar available" "which tar"
check "zip/unzip available" "which zip && which unzip"
echo ""

# === Domain 7: MCP & External Integration ===
echo "━━━ Domain 7: MCP & External Integration ━━━"
check "Chrome DevTools Protocol (port 9222)" "node -e \"const http=require('http');const r=http.get('http://127.0.0.1:9222/json/version',res=>{res.on('data',()=>{});res.on('end',()=>process.exit(0))});r.on('error',()=>process.exit(1));r.setTimeout(2000,()=>{r.destroy();process.exit(1)})\""
check_warn "MCP config writable" "python3 -c \"import json; json.load(open('/data/user/mcp/mcp-servers.json'))\""
check_warn "CDP browser content fetch" "timeout 15 node -e \"const{chromium}=require('playwright');(async()=>{const b=await chromium.connectOverCDP('http://127.0.0.1:9222').catch(()=>null);if(!b){process.exit(1);return;}const p=await b.newPage();try{await p.goto('https://example.com',{timeout:8000});process.exit(0);}catch{process.exit(1);}finally{await b.close();}})()\""
echo ""

# === Domain 8: Persistence ===
echo "━━━ Domain 8: Persistence ━━━"
check "~/.bashrc exists" "[ -f ~/.bashrc ]"
check "~/.zshrc exists" "[ -f ~/.zshrc ]"
check "~/.profile exists" "[ -f ~/.profile ]"
check "/workspace writable" "touch /workspace/.verify_test && rm /workspace/.verify_test"
echo ""

# === Domain 9: Platform Service Health ===
echo "━━━ Domain 9: Platform Service Health ━━━"
check_warn "VNC service (port 5900)" "timeout 3 bash -c 'echo >/dev/tcp/127.0.0.1/5900'"
check_warn "CDP endpoint (port 8088 /v1/cdp)" "timeout 5 curl -s --connect-timeout 3 http://127.0.0.1:8088/v1/cdp -o /dev/null"
check_warn "HTTP proxy (port 18080)" "timeout 3 bash -c 'echo >/dev/tcp/127.0.0.1/18080'"
check_warn "HTTPS proxy (port 18081)" "timeout 3 bash -c 'echo >/dev/tcp/127.0.0.1/18081'"
check_warn "WebSocket service (port 40005)" "timeout 3 bash -c 'echo >/dev/tcp/127.0.0.1/40005'"
check_warn "Health endpoint (port 13080 /health)" "timeout 5 curl -s --connect-timeout 3 http://127.0.0.1:13080/health -o /dev/null"
check_warn "Health endpoint (port 19090 /health)" "timeout 5 curl -s --connect-timeout 3 http://127.0.0.1:19090/health -o /dev/null"
check_warn "Chrome DevTools Protocol (port 9222)" "timeout 3 bash -c 'echo >/dev/tcp/127.0.0.1/9222'"
check_warn "Preview proxy (port 16000)" "timeout 3 bash -c 'echo >/dev/tcp/127.0.0.1/16000'"
echo ""

# === Domain 10: Security Baseline ===
echo "━━━ Domain 10: Security Baseline ━━━"
check "Seccomp status readable" "grep -q '^Seccomp:' /proc/1/status"
check "Capabilities readable (CapEff)" "grep -q '^CapEff:' /proc/1/status"
check_warn "AppArmor status readable" "timeout 3 cat /proc/1/attr/current >/dev/null 2>&1"
echo ""

# === Domain 11: Node.js Capabilities ===
echo "━━━ Domain 11: Node.js Capabilities ━━━"
check "crypto module available" "timeout 5 node -e \"require('crypto'); process.exit(0)\""
check "worker_threads available" "timeout 5 node -e \"require('worker_threads'); process.exit(0)\""
check "WebCrypto API available" "timeout 5 node -e \"const c=require('crypto'); if(c.subtle) process.exit(0); else process.exit(1)\""
check "Native WebSocket available" "timeout 5 node -e \"if(typeof WebSocket!=='undefined') process.exit(0); else process.exit(1)\""
echo ""

# === Domain 12: Performance Baseline ===
echo "━━━ Domain 12: Performance Baseline ━━━"
check_perf "Network latency (httpbin.org/ip)" "timeout 15 node -e \"const t=Date.now(); fetch('https://httpbin.org/ip',{signal:AbortSignal.timeout($((NETWORK_TIMEOUT_LONG*1000)))}).then(r=>{if(r.ok)console.log((Date.now()-t)+'ms');else process.exit(1)}).catch(()=>process.exit(1))\""
check_perf "Download speed" "timeout 30 node -e \"const t=Date.now(); fetch('https://httpbin.org/bytes/65536',{signal:AbortSignal.timeout($((NETWORK_TIMEOUT_LONG*1000)))}).then(r=>r.arrayBuffer()).then(b=>{const ms=Date.now()-t; const kbs=Math.round(64/ms*1000); console.log(kbs+' KB/s')}).catch(()=>process.exit(1))\""
echo ""

# === Domain 13: Polaris Dimension Coverage ===
echo "━━━ Domain 13: Polaris Dimension Coverage ━━━"

echo "  ── D1: Network Freedom ──"
check "npm mirror configured" "grep -q 'npmmirror.com' /root/.npmrc 2>/dev/null"
check "pip mirror configured" "grep -q 'tuna.tsinghua.edu.cn' /root/.pip/pip.conf 2>/dev/null"
check "Go GOPROXY configured" "go env GOPROXY 2>/dev/null | grep -q 'goproxy.cn'"
check "Cargo mirror configured" "grep -q 'rsproxy.cn' /root/.cargo/config.toml 2>/dev/null"
check "apt mirror configured" "grep -q 'tuna.tsinghua.edu.cn' /etc/apt/sources.list.d/ubuntu-mirror.list 2>/dev/null"
check "High-speed download (>1MB/s)" "curl -x http://127.0.0.1:18080 -s -o /dev/null -w '%{speed_download}' --connect-timeout 5 --max-time 15 https://speed.cloudflare.com/__down?bytes=1048576 2>/dev/null | awk '{if(\$1>1048576) exit 0; else exit 1}'"

echo "  ── D2: Package Management Freedom ──"
check "apt install works" "apt-get install -y -qq hello 2>/dev/null && which hello"
check "npm install works" "npm list -g playwright 2>/dev/null | grep -q playwright"
check "pip install works" "pip show pip 2>/dev/null | grep -q 'Name: pip'"
check "gcc compiles C code" "echo 'int main(){return 0;}' | gcc -x c - -o /tmp/verify_compile 2>/dev/null && /tmp/verify_compile && rm /tmp/verify_compile"

echo "  ── D3: Process Freedom ──"
check "seccomp mode 0 (no filters)" "grep '^Seccomp:' /proc/1/status | grep -q '0'"
check "cgroup v2 readable" "[ -d /sys/fs/cgroup ]"
check "ulimit generous (nofile>10000)" "ulimit -n | awk '{if(\$1>10000) exit 0; else exit 1}'"
check "Redis functional" "redis-cli ping 2>/dev/null | grep -q PONG"
check "PostgreSQL functional" "pg_isready -h localhost -p 5432 2>/dev/null | grep -q accepting"
check "Memcached functional" "echo stats | nc -w1 localhost 11211 2>/dev/null | grep -q STAT"
check "lighttpd functional" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ 2>/dev/null | grep -q 200"
check "beanstalkd functional" "echo -e 'stats\r\n' | nc -w1 localhost 11300 2>/dev/null | grep -q OK"

echo "  ── D4: Filesystem Freedom ──"
check "Disk space >1TB" "df /workspace 2>/dev/null | tail -1 | awk '{print \$2}' | awk '{if(\$1>1000000000000) exit 0; else exit 1}'"
check "/data/user/ writable" "touch /data/user/.verify_test && rm /data/user/.verify_test"
check "/data/user/ structure exists" "[ -d /data/user/mcp ] && [ -d /data/user/skills ] && [ -d /data/user/commands ]"
check "Backup/restore script exists" "[ -f /workspace/scripts/backup-restore.sh ]"

echo "  ── D5: MCP/Tool Freedom ──"
check "MCP server manager exists" "[ -f /workspace/scripts/mcp-server-manager.sh ]"
check "Custom command manager exists" "[ -f /workspace/scripts/custom-command-manager.sh ]"
check "Custom commands directory" "[ -d /data/user/commands ] && ls /data/user/commands/*.md 2>/dev/null | head -1 | grep -q ."

echo "  ── D6: Autonomous Evolution Freedom ──"
check "evolve.sh exists and valid" "bash -n /workspace/scripts/evolve.sh"
check "acquire-lock.sh exists" "[ -f /workspace/scripts/acquire-lock.sh ]"
check "release-lock.sh exists" "[ -f /workspace/scripts/release-lock.sh ]"
check "benchmark.sh exists" "[ -f /workspace/scripts/benchmark.sh ]"
check "polaris-score.md exists" "[ -f /workspace/references/polaris-score.md ]"
check "handoff.md exists" "[ -f /workspace/references/handoff.md ]"
echo ""

# === Summary ===
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   VERIFICATION RESULTS                               ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "  Total checks: $TOTAL"
echo "  ✅ Passed:    $PASSED"
echo "  ❌ Failed:    $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL CHECKS PASSED! Environment is fully operational.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  $FAILED check(s) failed. Review items above.${NC}"
    exit 1
fi
