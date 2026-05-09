#!/bin/bash
set -uo pipefail

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

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   ENVIRONMENT VERIFICATION                           ║"
echo "║   Full 8-Domain Validation                           ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# === Domain 1: Network ===
echo "━━━ Domain 1: Network ━━━"
check "DNS resolution" "nslookup google.com 2>&1 | grep -q 'Address'"
check "curl HTTP" "curl -s --connect-timeout 5 https://httpbin.org/ip -o /dev/null"
check "wget HTTP" "wget -q --timeout=5 https://httpbin.org/ip -O /dev/null"
check "Node.js fetch" "node -e \"fetch('https://httpbin.org/ip',{signal:AbortSignal.timeout(8000)}).then(r=>{if(r.ok)process.exit(0);else process.exit(1)}).catch(()=>process.exit(1))\""
check "Python urllib" "python3 -c \"import urllib.request; urllib.request.urlopen('https://httpbin.org/ip',timeout=5)\""
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
BROWSER=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
check "Playwright Chromium installed" "[ -n '$BROWSER' ] && [ -f '$BROWSER' ]"
if [ -n "$BROWSER" ] && [ -f "$BROWSER" ]; then
    check "Browser all libs satisfied" "ldd '$BROWSER' 2>&1 | grep -q 'not found'; [ \$? -ne 0 ]"
    check "Browser launches" "'$BROWSER' --version"
fi
check "Playwright Node module" "node -e \"require('playwright')\""
echo ""

# === Domain 6: Dev Toolchain ===
echo "━━━ Domain 6: Dev Toolchain ━━━"
check "git available" "which git"
check "git network access" "timeout 10 git ls-remote https://github.com/octocat/Hello-World.git HEAD 2>&1 | grep -qE '^[0-9a-f]{40}'"
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
echo ""

# === Domain 8: Persistence ===
echo "━━━ Domain 8: Persistence ━━━"
check "~/.bashrc exists" "[ -f ~/.bashrc ]"
check "~/.zshrc exists" "[ -f ~/.zshrc ]"
check "~/.profile exists" "[ -f ~/.profile ]"
check "/workspace writable" "touch /workspace/.verify_test && rm /workspace/.verify_test"
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
