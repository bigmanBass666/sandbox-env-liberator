#!/bin/bash
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/lib/config.sh" 2>/dev/null || true

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0

check() {
    TOTAL=$((TOTAL + 1))
    if eval "$2" &>/dev/null; then
        echo -e "${GREEN}[✅]${NC} $1"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}[❌]${NC} $1"
        FAILED=$((FAILED + 1))
    fi
}

check_warn() {
    TOTAL=$((TOTAL + 1))
    if eval "$2" &>/dev/null; then
        echo -e "${GREEN}[✅]${NC} $1"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}[⚠️]${NC} $1"
        FAILED=$((FAILED + 1))
    fi
}

check_perf() {
    TOTAL=$((TOTAL + 1))
    RESULT=$(eval "$2" 2>/dev/null)
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
