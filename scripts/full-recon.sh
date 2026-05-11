#!/bin/bash
# ============================================================
# Full Environment Reconnaissance Script
# Probes all 10 core domains of the cloud sandbox environment
# Outputs structured results for capability matrix generation
# ============================================================

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/lib/config.sh" 2>/dev/null || true

RECON_DIR="/tmp/sandbox-recon"
mkdir -p "$RECON_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; echo "PASS|$1" >> "$RECON_DIR/results.txt"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; echo "FAIL|$1" >> "$RECON_DIR/results.txt"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; echo "WARN|$1" >> "$RECON_DIR/results.txt"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; echo "INFO|$1" >> "$RECON_DIR/results.txt"; }
section() { echo ""; echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; echo -e "${CYAN}  DOMAIN $1: $2${NC}"; echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"; }

> "$RECON_DIR/results.txt"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   SANDBOX ENVIRONMENT FULL RECONNAISSANCE v2.0       ║"
echo "║   10-Domain Systematic Probe                         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# ============================================================
# DOMAIN 1: NETWORK
# ============================================================
section "1" "NETWORK LIMITATIONS"

echo "--- 1.1 DNS Resolution ---"
DNS_RESULT=$(nslookup google.com 2>&1)
if echo "$DNS_RESULT" | grep -q "Address.*#"; then
    pass "DNS resolution works (system resolver)"
else
    DNS_RESULT2=$(node -e "const dns=require('dns');dns.lookup('google.com',(e,a)=>console.log(e?'FAIL:'+e.message:'OK:'+a))" 2>&1)
    if echo "$DNS_RESULT2" | grep -q "^OK:"; then
        pass "DNS via Node.js works (IP: $(echo $DNS_RESULT2 | cut -d: -f2))"
    else
        fail "DNS resolution blocked entirely"
    fi
fi

DNS_SERVER=$(cat /etc/resolv.conf 2>/dev/null | grep "^nameserver" | head -1 | awk '{print $2}')
info "DNS server: ${DNS_SERVER:-unknown}"

echo "--- 1.2 CLI Network (curl/wget) ---"
CURL_OK=0
if curl -s --connect-timeout $NETWORK_TIMEOUT_SHORT https://httpbin.org/ip -o /tmp/sandbox-recon/curl_test 2>/dev/null && [ -s /tmp/sandbox-recon/curl_test ]; then
    pass "curl: WORKING"
    CURL_OK=1
else
    fail "curl: BLOCKED or FAILED"
fi

WGET_OK=0
if wget -q --timeout=$NETWORK_TIMEOUT_SHORT https://httpbin.org/ip -O /tmp/sandbox-recon/wget_test 2>/dev/null && [ -s /tmp/sandbox-recon/wget_test ]; then
    pass "wget: WORKING"
    WGET_OK=1
else
    fail "wget: BLOCKED or FAILED"
fi

echo "--- 1.3 Node.js fetch() ---"
NODE_FETCH=$(node -e "
fetch('https://httpbin.org/ip',{signal:AbortSignal.timeout($((NETWORK_TIMEOUT_LONG*1000)))})
  .then(r=>r.json())
  .then(d=>console.log('OK:'+d.origin))
  .catch(e=>console.log('FAIL:'+e.message.substring(0,60)))
" 2>&1)
if echo "$NODE_FETCH" | grep -q "^OK:"; then
    pass "Node.js fetch(): WORKING (IP: $(echo $NODE_FETCH | cut -d: -f2-))"
else
    fail "Node.js fetch(): $(echo $NODE_FETCH | cut -d: -f2-)"
fi

echo "--- 1.4 Python urllib ---"
PY_NET=$(python3 -c "
import urllib.request, ssl
ssl._create_default_https_context = ssl._create_unverified_context
try:
    r=urllib.request.urlopen('https://httpbin.org/ip',timeout=$NETWORK_TIMEOUT_MEDIUM)
    print('OK:'+r.read().decode()[:30])
except Exception as e:
    print('FAIL:'+str(e)[:60])
" 2>&1)
if echo "$PY_NET" | grep -q "^OK:"; then
    pass "Python urllib: WORKING"
else
    fail "Python urllib: $(echo $PY_NET | cut -d: -f2-)"
fi

echo "--- 1.5 Go net/http ---"
cat > /tmp/go_net_check.go << 'GOEOF'
package main
import ("fmt";"net/http";"io";"time")
func main(){c:=&http.Client{Timeout:${NETWORK_TIMEOUT_MEDIUM}*time.Second};r,err:=c.Get("https://httpbin.org/ip");if err!=nil{fmt.Println("FAIL:"+err.Error()[:60]);return};defer r.Body.Close();b,_:=io.ReadAll(r.Body);fmt.Println("OK:"+string(b)[:30])}
GOEOF
GO_NET=$(go run /tmp/go_net_check.go 2>&1)
rm -f /tmp/go_net_check.go
if echo "$GO_NET" | grep -q "^OK:"; then
    pass "Go net/http: WORKING"
else
    fail "Go net/http: $(echo "$GO_NET" | head -1 | cut -c1-80)"
fi

echo "--- 1.6 apt network ---"
APT_TEST=$(apt-get update 2>&1 | tail -3)
if echo "$APT_TEST" | grep -qi "error\|failed\|could not"; then
    fail "apt-get update: BLOCKED"
    echo "$APT_TEST" | head -2 | sed 's/^/     /'
else
    pass "apt-get update: WORKING"
fi

echo "--- 1.7 Port Connectivity ---"
info "Testing common ports via Node.js..."
node -e "
const net=require('net');
const ports=[22,80,443,3000,5432,6379,8080,8443,9222,9090];
const host='0.0.0.0';
ports.forEach(p=>{
  const s=net.createConnection({host,port:p,timeout:1500},()=>{
    console.log('PORT_OPEN|'+p);
    s.destroy();
  });
  s.on('error',()=>console.log('PORT_CLOSED|'+p));
  s.on('timeout',()=>{console.log('PORT_TIMEOUT|'+p);s.destroy()});
});
" 2>&1 | sort | while read line; do
    port=$(echo "$line" | cut -d'|' -f2)
    status=$(echo "$line" | cut -d'|' -f1)
    case $status in
        PORT_OPEN) pass "Port $port: OPEN (locally listening)" ;;
        PORT_CLOSED) info "Port $port: CLOSED" ;;
        PORT_TIMEOUT) info "Port $port: TIMEOUT" ;;
    esac
done

echo "--- 1.8 Outbound Port Test ---"
node -e "
const net=require('net');
const targets=[
  ['httpbin.org',80,'HTTP'],
  ['httpbin.org',443,'HTTPS'],
  ['httpbin.org',8080,'HTTP-ALT'],
  ['google.com',443,'Google-HTTPS'],
  ['github.com',443,'GitHub-HTTPS'],
  ['registry.npmjs.org',443,'NPM-REGISTRY'],
];
let done=0;
targets.forEach(([h,p,n])=>{
  const s=net.createConnection({host:h,port:p,timeout:$((NETWORK_TIMEOUT_MEDIUM*1000))},()=>{
    console.log('OUT_OK|'+n+'|'+h+':'+p);
    s.destroy();done++;if(done===targets.length)process.exit(0);
  });
  s.on('error',()=>{console.log('OUT_FAIL|'+N+'|'+h+':'+p);s.destroy();done++;if(done===targets.length)process.exit(0)});
  s.on('timeout',()=>{console.log('OUT_TIMEOUT|'+n+'|'+h+':'+p);s.destroy();done++;if(done===targets.length)process.exit(0)});
});
setTimeout(()=>process.exit(0),$((NETWORK_TIMEOUT_LONG*1000)));
" 2>&1 | sort | while read line; do
    name=$(echo "$line" | cut -d'|' -f2)
    target=$(echo "$line" | cut -d'|' -f3)
    status=$(echo "$line" | cut -d'|' -f1)
    case $status in
        OUT_OK) pass "Outbound $name ($target): REACHABLE" ;;
        OUT_FAIL) fail "Outbound $name ($target): UNREACHABLE" ;;
        OUT_TIMEOUT) warn "Outbound $name ($target): TIMEOUT" ;;
    esac
done

echo "--- 1.9 HTTP Proxy Detection ---"
for var in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY; do
    val="${!var}"
    if [ -n "$val" ]; then
        info "Proxy env: $var=$val"
    fi
done
if [ -z "$http_proxy" ] && [ -z "$https_proxy" ]; then
    info "No proxy environment variables set"
fi

echo "--- 1.10 IPv6 ---"
IPV6=$(node -e "
const dns=require('dns');
dns.lookup('google.com',{family:6},(e,a)=>console.log(e?'FAIL':'OK:'+a))
" 2>&1)
if echo "$IPV6" | grep -q "^OK:"; then
    pass "IPv6 resolution: WORKS"
else
    info "IPv6: NOT AVAILABLE"
fi

# ============================================================
# DOMAIN 2: FILE SYSTEM & PERMISSIONS
# ============================================================
section "2" "FILE SYSTEM & PERMISSIONS"

echo "--- 2.1 Writable Directories ---"
for dir in /tmp /root /root/.local /root/.local/bin /home /var/tmp /var/log /usr/local/bin /usr/local/lib /usr/local/share /opt /etc/ld.so.conf.d /etc/profile.d /srv; do
    if [ -d "$dir" ]; then
        if touch "$dir/.sandbox_write_test" 2>/dev/null && rm "$dir/.sandbox_write_test" 2>/dev/null; then
            pass "$dir: WRITABLE"
        else
            fail "$dir: NOT WRITABLE"
        fi
    else
        info "$dir: DOES NOT EXIST"
    fi
done

echo "--- 2.2 Disk Space & Quota ---"
df -h / /tmp /home 2>/dev/null | while read line; do info "$line"; done
QUOTA=$(quota 2>&1)
if echo "$QUOTA" | grep -qi "none\|no quota"; then
    pass "No disk quota enforced"
elif [ -n "$QUOTA" ]; then
    warn "Disk quota detected: $QUOTA"
else
    info "quota command not available or no output"
fi

echo "--- 2.3 /etc/ld.so.conf.d Writability ---"
if touch /etc/ld.so.conf.d/.sandbox_test 2>/dev/null && rm /etc/ld.so.conf.d/.sandbox_test 2>/dev/null; then
    pass "/etc/ld.so.conf.d: WRITABLE (dynamic library injection possible)"
else
    fail "/etc/ld.so.conf.d: NOT WRITABLE (must use LD_LIBRARY_PATH)"
fi

echo "--- 2.4 ldconfig ---"
if ldconfig 2>/dev/null; then
    pass "ldconfig: EXECUTABLE"
else
    warn "ldconfig: FAILED (library cache may not update, but LD_LIBRARY_PATH still works)"
fi

echo "--- 2.5 Symlink Capabilities ---"
ln -sf /tmp /tmp/sandbox_symlink_test 2>/dev/null && rm /tmp/sandbox_symlink_test 2>/dev/null
if [ $? -eq 0 ]; then
    pass "Symlinks: WORKING"
else
    fail "Symlinks: BLOCKED"
fi

echo "--- 2.6 Hardlink Capabilities ---"
touch /tmp/sandbox_hardlink_src 2>/dev/null && ln /tmp/sandbox_hardlink_src /tmp/sandbox_hardlink_dst 2>/dev/null
if [ $? -eq 0 ]; then
    pass "Hardlinks: WORKING"
    rm /tmp/sandbox_hardlink_src /tmp/sandbox_hardlink_dst 2>/dev/null
else
    fail "Hardlinks: BLOCKED"
fi

echo "--- 2.7 Mount Points ---"
info "Current mount points:"
mount 2>/dev/null | grep -E "^/dev|tmpfs|overlay" | while read line; do info "  $line"; done

echo "--- 2.8 tmpfs/shm ---"
if [ -d "/dev/shm" ]; then
    SHM_SIZE=$(df -h /dev/shm 2>/dev/null | tail -1 | awk '{print $2}')
    pass "/dev/shm: EXISTS (size: $SHM_SIZE)"
    if touch /dev/shm/.sandbox_test 2>/dev/null && rm /dev/shm/.sandbox_test 2>/dev/null; then
        pass "/dev/shm: WRITABLE"
    else
        fail "/dev/shm: NOT WRITABLE"
    fi
else
    fail "/dev/shm: NOT AVAILABLE"
fi

echo "--- 2.9 Container Capabilities ---"
CAPS=$(cat /proc/1/status 2>/dev/null | grep "^CapEff:" | awk '{print $2}')
if [ -n "$CAPS" ]; then
    info "Effective capabilities: $CAPS"
    if [ "$CAPS" = "0000003fffffffff" ]; then
        pass "Full capabilities (privileged container)"
    else
        warn "Limited capabilities: $CAPS"
    fi
else
    info "Cannot read capabilities"
fi

echo "--- 2.10 File Descriptor Limits ---"
ULIMIT_SOFT=$(ulimit -Sn 2>/dev/null)
ULIMIT_HARD=$(ulimit -Hn 2>/dev/null)
info "File descriptors: soft=$ULIMIT_SOFT hard=$ULIMIT_HARD"

echo "--- 2.11 /proc Access ---"
PROC_ITEMS=0
for item in cpuinfo meminfo mounts self status cmdline version; do
    if [ -r "/proc/$item" ]; then
        PROC_ITEMS=$((PROC_ITEMS + 1))
    fi
done
if [ $PROC_ITEMS -ge 5 ]; then
    pass "/proc filesystem: ACCESSIBLE ($PROC_ITEMS/6 key items readable)"
else
    warn "/proc filesystem: PARTIALLY ACCESSIBLE ($PROC_ITEMS/6 key items readable)"
fi

# ============================================================
# DOMAIN 3: PROCESS & RESOURCES
# ============================================================
section "3" "PROCESS & RESOURCES"

echo "--- 3.1 Process Management ---"
SELF_PID=$$
info "Current PID: $SELF_PID"

if nohup echo test > /dev/null 2>&1; then
    pass "nohup: AVAILABLE"
else
    fail "nohup: NOT AVAILABLE"
fi

for cmd in screen tmux; do
    if which $cmd &>/dev/null; then
        pass "$cmd: AVAILABLE ($(which $cmd))"
    else
        fail "$cmd: NOT AVAILABLE"
    fi
done

echo "--- 3.2 Background Process Test ---"
node -e "
const{spawn}=require('child_process');
const p=spawn('sleep',['30'],{detached:true,stdio:'ignore'});
p.unref();
console.log('BG_PID:'+p.pid);
setTimeout(()=>{
  try{process.kill(p.pid,0);console.log('BG_ALIVE:1');process.kill(p.pid,'SIGKILL')}
  catch(e){console.log('BG_ALIVE:0')}
},500);
" 2>&1 | while read line; do
    case $line in
        BG_PID:*) info "Background process PID: ${line#BG_PID:}" ;;
        BG_ALIVE:1) pass "Background processes: CAN RUN DETACHED" ;;
        BG_ALIVE:0) fail "Background processes: KILLED IMMEDIATELY" ;;
    esac
done

echo "--- 3.3 Resource Limits ---"
for limit in core data fsize memlock nofile rss stack cpu nproc; do
    VAL=$(ulimit -$limit 2>/dev/null)
    info "ulimit $limit: ${VAL:-unlimited}"
done

echo "--- 3.4 cgroup Limits ---"
if [ -d /sys/fs/cgroup ]; then
    CGROUP_TYPE=$(ls /sys/fs/cgroup/ 2>/dev/null | head -5 | tr '\n' ' ')
    info "cgroup directories: $CGROUP_TYPE"
    
    if [ -f /sys/fs/cgroup/memory.max ]; then
        MEM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
        info "cgroup memory.max: ${MEM_MAX:-unknown}"
    elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        MEM_LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        info "cgroup memory limit: ${MEM_LIMIT:-unknown}"
    fi
    
    if [ -f /sys/fs/cgroup/cpu.max ]; then
        CPU_MAX=$(cat /sys/fs/cgroup/cpu.max 2>/dev/null)
        info "cgroup cpu.max: ${CPU_MAX:-unknown}"
    fi
else
    info "cgroup filesystem not accessible"
fi

echo "--- 3.5 Memory ---"
free -h 2>/dev/null | while read line; do info "$line"; done

echo "--- 3.6 CPU ---"
CPU_COUNT=$(nproc 2>/dev/null || echo "unknown")
CPU_MODEL=$(cat /proc/cpuinfo 2>/dev/null | grep "model name" | head -1 | cut -d: -f2 | xargs)
info "CPU count: $CPU_COUNT"
info "CPU model: ${CPU_MODEL:-unknown}"

echo "--- 3.7 ptrace/strace ---"
if which strace &>/dev/null; then
    STRACE_TEST=$(strace -e trace=write echo test 2>&1 | tail -1)
    if [ -n "$STRACE_TEST" ]; then
        pass "strace: WORKING"
    else
        fail "strace: BLOCKED"
    fi
else
    info "strace: NOT INSTALLED"
fi

echo "--- 3.8 Docker-in-Docker ---"
if which docker &>/dev/null; then
    DOCKER_TEST=$(docker info 2>&1 | head -3)
    if echo "$DOCKER_TEST" | grep -qi "error\|denied\|cannot"; then
        fail "Docker: INSTALLED but NOT ACCESSIBLE"
    else
        pass "Docker: ACCESSIBLE"
    fi
else
    info "Docker: NOT INSTALLED"
fi

if which podman &>/dev/null; then
    pass "Podman: AVAILABLE"
else
    info "Podman: NOT INSTALLED"
fi

# ============================================================
# DOMAIN 4: PACKAGE MANAGEMENT & SOFTWARE INSTALLATION
# ============================================================
section "4" "PACKAGE MANAGEMENT & SOFTWARE INSTALLATION"

echo "--- 4.1 apt/dpkg ---"
if which apt-get &>/dev/null; then
    pass "apt-get: AVAILABLE"
    APT_INSTALL=$(apt-get install -y -s hello 2>&1 | tail -3)
    if echo "$APT_INSTALL" | grep -qi "error\|failed\|unable"; then
        fail "apt-get install: SIMULATION FAILED (network likely blocked)"
    else
        pass "apt-get install: SIMULATION PASSED"
    fi
else
    fail "apt-get: NOT AVAILABLE"
fi

if which dpkg &>/dev/null; then
    pass "dpkg: AVAILABLE"
else
    fail "dpkg: NOT AVAILABLE"
fi

echo "--- 4.2 pip ---"
if which pip &>/dev/null || which pip3 &>/dev/null; then
    PIP_CMD=$(which pip3 2>/dev/null || which pip 2>/dev/null)
    pass "pip: AVAILABLE ($PIP_CMD)"
    PIP_VER=$($PIP_CMD --version 2>&1 | head -1)
    info "pip version: $PIP_VER"
    PIP_INSTALL=$($PIP_CMD install --dry-run requests 2>&1 | tail -2)
    if echo "$PIP_INSTALL" | grep -qi "error\|failed"; then
        warn "pip install: DRY-RUN HAD ISSUES"
    else
        pass "pip install: DRY-RUN OK"
    fi
    PIP_TARGET=$($PIP_CMD install --target /tmp/pip_test --dry-run requests 2>&1 | tail -2)
    if [ $? -eq 0 ]; then
        pass "pip --target: SUPPORTED (user-directory install possible)"
    else
        warn "pip --target: MAY NOT WORK"
    fi
else
    fail "pip: NOT AVAILABLE"
fi

echo "--- 4.3 npm/npx ---"
if which npm &>/dev/null; then
    pass "npm: AVAILABLE ($(npm --version 2>/dev/null))"
else
    fail "npm: NOT AVAILABLE"
fi

if which npx &>/dev/null; then
    pass "npx: AVAILABLE"
    NPX_TEST=$(timeout 15 npx -y cowsay hello 2>&1 | head -3)
    if [ $? -eq 0 ]; then
        pass "npx -y: WORKS (can execute remote packages)"
    else
        warn "npx -y: MAY NOT WORK (network?)"
    fi
else
    fail "npx: NOT AVAILABLE"
fi

echo "--- 4.4 Go modules ---"
if which go &>/dev/null; then
    pass "Go: AVAILABLE ($(go version 2>/dev/null))"
    GO_ENV=$(go env GOPATH GOMODCACHE 2>/dev/null)
    info "Go env: $GO_ENV"
else
    fail "Go: NOT AVAILABLE"
fi

echo "--- 4.5 Cargo/Rust ---"
if which cargo &>/dev/null; then
    pass "Cargo: AVAILABLE ($(cargo --version 2>/dev/null))"
else
    info "Cargo: NOT INSTALLED"
    if [ -d "$HOME/.cargo" ]; then
        info "  .cargo directory exists"
    fi
fi

echo "--- 4.6 Binary Download & Execute ---"
BIN_TEST=$(node -e "
fetch('https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64',{signal:AbortSignal.timeout(15000)})
  .then(r=>{if(!r.ok)throw new Error('HTTP '+r.status);return r.arrayBuffer()})
  .then(b=>{
    require('fs').writeFileSync('/tmp/jq-test',Buffer.from(b));
    require('child_process').execSync('chmod +x /tmp/jq-test');
    const ver=require('child_process').execSync('/tmp/jq-test --version').toString().trim();
    console.log('OK:'+ver);
    require('fs').unlinkSync('/tmp/jq-test');
  })
  .catch(e=>console.log('FAIL:'+e.message.substring(0,60)));
" 2>&1)
if echo "$BIN_TEST" | grep -q "^OK:"; then
    pass "Binary download+execute: WORKS ($(echo $BIN_TEST | cut -d: -f2-))"
else
    fail "Binary download+execute: $(echo $BIN_TEST | cut -d: -f2-)"
fi

echo "--- 4.7 Source Compilation ---"
if which gcc &>/dev/null; then
    pass "gcc: AVAILABLE"
    COMPILE_TEST=$(echo '#include<stdio.h>
int main(){printf("COMPILE_OK");return 0;}' > /tmp/test.c && gcc -o /tmp/test_bin /tmp/test.c 2>&1 && /tmp/test_bin 2>&1)
    if echo "$COMPILE_TEST" | grep -q "COMPILE_OK"; then
        pass "C compilation+execution: WORKS"
    else
        fail "C compilation: FAILED"
    fi
    rm -f /tmp/test.c /tmp/test_bin
else
    info "gcc: NOT INSTALLED"
fi

if which g++ &>/dev/null; then
    pass "g++: AVAILABLE"
else
    info "g++: NOT INSTALLED"
fi

if which make &>/dev/null; then
    pass "make: AVAILABLE"
else
    info "make: NOT INSTALLED"
fi

if which cmake &>/dev/null; then
    pass "cmake: AVAILABLE"
else
    info "cmake: NOT INSTALLED"
fi

# ============================================================
# DOMAIN 5: BROWSER & GUI
# ============================================================
section "5" "BROWSER & GUI"

echo "--- 5.1 Browser Detection ---"
PW_CHROME=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
PW_HEADLESS=$(find /root/.cache/ms-playwright -name "chrome-headless-shell" -type f 2>/dev/null | head -1)
GOOGLE_CHROME=$(which google-chrome 2>/dev/null || ls /opt/google/chrome/chrome 2>/dev/null)
CHROMIUM=$(which chromium-browser 2>/dev/null || which chromium 2>/dev/null)
FIREFOX=$(which firefox 2>/dev/null)

[ -n "$PW_CHROME" ] && pass "Playwright Chromium: $PW_CHROME" || fail "Playwright Chromium: NOT FOUND"
[ -n "$PW_HEADLESS" ] && pass "Playwright Headless Shell: $PW_HEADLESS" || warn "Playwright Headless Shell: NOT FOUND"
[ -n "$GOOGLE_CHROME" ] && pass "Google Chrome: $GOOGLE_CHROME" || fail "Google Chrome: NOT FOUND"
[ -n "$CHROMIUM" ] && pass "Chromium: $CHROMIUM" || info "Chromium: NOT FOUND"
[ -n "$FIREFOX" ] && pass "Firefox: $FIREFOX" || info "Firefox: NOT FOUND"

echo "--- 5.2 Browser Library Dependencies ---"
BROWSER="${PW_CHROME:-$GOOGLE_CHROME}"
if [ -n "$BROWSER" ] && [ -f "$BROWSER" ]; then
    MISSING=$(ldd "$BROWSER" 2>&1 | grep "not found" | awk '{print $1}' | sort -u)
    if [ -z "$MISSING" ]; then
        pass "Browser libraries: ALL SATISFIED"
    else
        COUNT=$(echo "$MISSING" | wc -l)
        fail "Browser libraries: $COUNT MISSING"
        echo "$MISSING" | sed 's/^/     /'
    fi
fi

echo "--- 5.3 xvfb/VNC ---"
for cmd in Xvfb xvfb-run Xvnc x11vnc noVNC; do
    if which $cmd &>/dev/null; then
        pass "$cmd: AVAILABLE"
    else
        info "$cmd: NOT INSTALLED"
    fi
done

echo "--- 5.4 Display Server ---"
if [ -n "$DISPLAY" ]; then
    pass "DISPLAY env: $DISPLAY"
else
    info "DISPLAY env: NOT SET (headless mode)"
fi

echo "--- 5.5 Chrome Launch Test ---"
if [ -n "$BROWSER" ] && [ -f "$BROWSER" ]; then
    BROWSER_VER=$("$BROWSER" --version 2>&1 | head -1)
    if [ -n "$BROWSER_VER" ]; then
        pass "Browser launch: $BROWSER_VER"
    else
        fail "Browser launch: FAILED (missing deps?)"
    fi
fi

echo "--- 5.6 Playwright Module ---"
PW_MOD=$(node -e "try{require('playwright');console.log('OK')}catch(e){console.log('FAIL:'+e.message.substring(0,60))}" 2>&1)
if echo "$PW_MOD" | grep -q "^OK"; then
    pass "Playwright Node module: AVAILABLE"
else
    fail "Playwright Node module: NOT FOUND"
fi

echo "--- 5.7 VS Code Server ---"
if which code-server &>/dev/null; then
    pass "code-server: AVAILABLE"
elif [ -d "/root/.vscode-server" ]; then
    pass "VS Code Server: directory exists"
else
    info "VS Code Server: NOT DETECTED"
fi

# ============================================================
# DOMAIN 6: DEVELOPMENT TOOLCHAIN
# ============================================================
section "6" "DEVELOPMENT TOOLCHAIN COMPLETENESS"

echo "--- 6.1 Version Control ---"
if which git &>/dev/null; then
    pass "git: $(git --version 2>/dev/null)"
    GIT_CLONE=$(timeout 10 git ls-remote https://github.com/octocat/Hello-World.git HEAD 2>&1 | head -1)
    if echo "$GIT_CLONE" | grep -qE "^[0-9a-f]{40}"; then
        pass "git clone: NETWORK ACCESSIBLE"
    else
        fail "git clone: NETWORK BLOCKED ($(echo $GIT_CLONE | head -c 60))"
    fi
else
    fail "git: NOT AVAILABLE"
fi

echo "--- 6.2 Databases ---"
if which sqlite3 &>/dev/null; then
    pass "SQLite3: AVAILABLE"
    SQLITE_TEST=$(sqlite3 :memory: "SELECT 'SQLITE_OK';" 2>&1)
    [ "$SQLITE_TEST" = "SQLITE_OK" ] && pass "SQLite3: FUNCTIONAL" || fail "SQLite3: NOT FUNCTIONAL"
else
    info "SQLite3: NOT INSTALLED"
fi

for db in psql redis-cli mongosh mysql; do
    if which $db &>/dev/null; then
        pass "$db: AVAILABLE"
    else
        info "$db: NOT INSTALLED"
    fi
done

echo "--- 6.3 Language Runtimes ---"
for lang in "node:Node.js" "python3:Python" "go:Go" "java:Java" "ruby:Ruby" "php:PHP" "rustc:Rust" "dotnet:.NET" "swift:Swift" "scala:Scala" "elixir:Elixir" "erl:Erlang" "bun:Bun" "deno:Deno"; do
    cmd=$(echo $lang | cut -d: -f1)
    name=$(echo $lang | cut -d: -f2)
    if which $cmd &>/dev/null; then
        VER=$(timeout 5 $cmd --version 2>/dev/null | head -1)
        if [ -n "$VER" ]; then
            pass "$name: $VER"
        else
            pass "$name: AVAILABLE (version timeout)"
        fi
    else
        info "$name: NOT FOUND"
    fi
done

echo "--- 6.4 Build Tools ---"
for tool in make cmake gradle mvn ant webpack vite rollup esbuild parcel turbo bazel; do
    if which $tool &>/dev/null; then
        VER=$(timeout 5 $tool --version 2>/dev/null | head -1)
        pass "$tool: ${VER:-AVAILABLE}"
    else
        info "$tool: NOT FOUND"
    fi
done

echo "--- 6.5 Cloud CLI ---"
for cli in aws gcloud az doctl hcloud fly vercel netlify heroku; do
    if which $cli &>/dev/null; then
        pass "$cli: AVAILABLE"
    else
        info "$cli: NOT INSTALLED"
    fi
done

echo "--- 6.6 Container Tools ---"
for tool in docker podman kubectl helm kustomize skopeo buildah; do
    if which $tool &>/dev/null; then
        pass "$tool: AVAILABLE"
    else
        info "$tool: NOT INSTALLED"
    fi
done

echo "--- 6.7 SSH ---"
if which ssh &>/dev/null; then
    pass "SSH client: AVAILABLE"
    SSH_KEY=$(ls ~/.ssh/id_* 2>/dev/null | head -3)
    if [ -n "$SSH_KEY" ]; then
        info "SSH keys found: $SSH_KEY"
    else
        info "No SSH keys found"
    fi
else
    info "SSH client: NOT AVAILABLE"
fi

echo "--- 6.8 Archive Tools ---"
for tool in tar gzip bzip2 xz zip unzip 7z; do
    if which $tool &>/dev/null; then
        pass "$tool: AVAILABLE"
    else
        info "$tool: NOT FOUND"
    fi
done

# ============================================================
# DOMAIN 7: MCP & EXTERNAL INTEGRATION
# ============================================================
section "7" "MCP & EXTERNAL INTEGRATION"

echo "--- 7.1 MCP Tool Inventory ---"
info "MCP tools are available via the SOLO platform, not directly from CLI"
info "Known MCP categories:"
info "  - Playwright MCP: Browser automation (navigate, click, fill, screenshot, etc.)"
info "  - Memory MCP: Knowledge graph (create/read/search entities and relations)"
info "  - Context7 MCP: Documentation lookup (resolve-library-id, query-docs)"
info "  - WebFetch: URL content fetching"
info "  - Schedule: Cron-based task scheduling"

echo "--- 7.2 Memory MCP Persistence ---"
MEM_DIR=$(find / -name "memory.json" -o -name "memory.jsonl" 2>/dev/null | head -3)
if [ -n "$MEM_DIR" ]; then
    pass "Memory MCP storage found: $MEM_DIR"
else
    info "Memory MCP storage: location unknown (may be in platform-managed path)"
fi

echo "--- 7.3 Playwright MCP Browser Status ---"
PW_MCP=$(node -e "
const http=require('http');
const req=http.get('http://127.0.0.1:9222/json/version',r=>{
  let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log('CDP_OK:'+d.substring(0,80)));
});
req.on('error',e=>console.log('CDP_FAIL:'+e.message.substring(0,40)));
req.setTimeout(2000,()=>{console.log('CDP_TIMEOUT');req.destroy()});
" 2>&1)
if echo "$PW_MCP" | grep -q "^CDP_OK:"; then
    pass "Chrome DevTools Protocol: ACCESSIBLE on port 9222"
else
    info "Chrome DevTools Protocol: NOT ACTIVE (browser not running with --remote-debugging-port)"
fi

# ============================================================
# DOMAIN 8: PERSISTENCE & SESSION RECOVERY
# ============================================================
section "8" "PERSISTENCE & SESSION RECOVERY"

echo "--- 8.1 Filesystem Persistence Test ---"
PERSIST_MARKER="/workspace/.sandbox-persist-test-$(date +%s)"
echo "persistence-test-$(date +%s)" > "$PERSIST_MARKER"
if [ -f "$PERSIST_MARKER" ]; then
    pass "File write: SUCCESS (marker: $PERSIST_MARKER)"
    info "  (Check in next session if marker still exists)"
else
    fail "File write: FAILED"
fi

echo "--- 8.2 Environment Variable Persistence ---"
if [ -f ~/.bashrc ]; then
    pass "~/.bashrc: EXISTS"
    BASHRC_LINES=$(wc -l < ~/.bashrc)
    info "~/.bashrc: $BASHRC_LINES lines"
else
    warn "~/.bashrc: DOES NOT EXIST"
fi

if [ -f ~/.zshrc ]; then
    pass "~/.zshrc: EXISTS"
else
    info "~/.zshrc: DOES NOT EXIST"
fi

if [ -f ~/.profile ]; then
    pass "~/.profile: EXISTS"
else
    info "~/.profile: DOES NOT EXIST"
fi

echo "--- 8.3 npm Global Packages ---"
if which npm &>/dev/null; then
    NPM_GLOBAL=$(npm list -g --depth=0 2>/dev/null | tail -20)
    NPM_COUNT=$(echo "$NPM_GLOBAL" | grep -c "^[├└]" 2>/dev/null || echo 0)
    info "npm global packages: $NPM_COUNT installed"
    echo "$NPM_GLOBAL" | head -15 | while read line; do info "  $line"; done
fi

echo "--- 8.4 pip Packages ---"
if which pip3 &>/dev/null; then
    PIP_COUNT=$(pip3 list 2>/dev/null | wc -l)
    info "pip packages: ~$PIP_COUNT installed"
fi

echo "--- 8.5 mise/rtx Tool Versions ---"
if which mise &>/dev/null; then
    pass "mise: AVAILABLE"
    MISE_TOOLS=$(mise list 2>/dev/null | head -20)
    info "mise installed tools:"
    echo "$MISE_TOOLS" | while read line; do info "  $line"; done
else
    info "mise: NOT INSTALLED"
fi

echo "--- 8.6 Shell History ---"
for hist_file in ~/.bash_history ~/.zsh_history ~/.history; do
    if [ -f "$hist_file" ]; then
        HIST_LINES=$(wc -l < "$hist_file")
        info "$hist_file: $HIST_LINES lines"
    fi
done

# ============================================================
# DOMAIN 9: PLATFORM INTERNAL SERVICES
# ============================================================
section "9" "PLATFORM INTERNAL SERVICES"

echo "--- 9.1 Full Port Scan (1-65535) ---"
node -e "
const net=require('net');
const OPEN=[];
let checked=0;
const total=65535;
const BATCH=500;
const ports=[];
for(let i=1;i<=total;i++) ports.push(i);

function scanBatch(offset){
  const batch=ports.slice(offset,offset+BATCH);
  if(batch.length===0){
    console.log('SCAN_DONE|'+OPEN.length+'|'+OPEN.join(','));
    return;
  }
  let pending=0;
  batch.forEach(p=>{
    pending++;
    const s=net.createConnection({host:'127.0.0.1',port:p,timeout:400},()=>{
      OPEN.push(p);s.destroy();pending--;
      if(pending===0) scanBatch(offset+BATCH);
    });
    s.on('error',()=>{s.destroy();pending--;if(pending===0) scanBatch(offset+BATCH)});
    s.on('timeout',()=>{s.destroy();pending--;if(pending===0) scanBatch(offset+BATCH)});
  });
}
scanBatch(0);
setTimeout(()=>console.log('SCAN_TIMEOUT|'+OPEN.length+'|'+OPEN.join(',')),60000);
" 2>&1 | while IFS= read -r line; do
    count=$(echo "$line" | cut -d'|' -f2)
    ports_str=$(echo "$line" | cut -d'|' -f3)
    case "$line" in
        SCAN_DONE*) pass "Full port scan: $count open ports found"; [ -n "$ports_str" ] && info "Open ports: $ports_str" ;;
        SCAN_TIMEOUT*) warn "Full port scan: timed out, $count ports found so far"; [ -n "$ports_str" ] && info "Open ports: $ports_str" ;;
    esac
done

echo "--- 9.2 VNC Service (port 5900) ---"
VNC_RESULT=$(node -e "
const net=require('net');
let done=false;
const s=net.createConnection({host:'127.0.0.1',port:5900,timeout:3000},()=>{
  s.on('data',d=>{
    if(done)return;done=true;
    const hdr=d.toString('utf8',0,Math.min(12,d.length));
    if(hdr.startsWith('RFB')){console.log('VNC_OK:'+hdr.trim())}else{console.log('VNC_UNKNOWN:'+hdr.trim().substring(0,30))}
    s.destroy();
  });
  s.on('error',()=>{if(!done){done=true;console.log('VNC_FAIL:read error');s.destroy()}});
  setTimeout(()=>{if(!done){done=true;console.log('VNC_TIMEOUT:no data');s.destroy()}},2000);
});
s.on('error',e=>{if(!done){done=true;console.log('VNC_FAIL:'+e.message.substring(0,40))}});
s.on('timeout',()=>{if(!done){done=true;console.log('VNC_TIMEOUT');s.destroy()}});
" 2>&1)
if echo "$VNC_RESULT" | grep -q "^VNC_OK:"; then
    pass "VNC service: DETECTED ($(echo $VNC_RESULT | cut -d: -f2-))"
elif echo "$VNC_RESULT" | grep -q "^VNC_UNKNOWN:"; then
    warn "VNC port 5900: OPEN but not RFB protocol"
elif echo "$VNC_RESULT" | grep -q "^VNC_TIMEOUT"; then
    warn "VNC port 5900: connected but no RFB handshake"
else
    info "VNC service: NOT DETECTED on port 5900"
fi

echo "--- 9.3 CDP Endpoint (port 8088, /v1/cdp) ---"
CDP_RESULT=$(node -e "
const http=require('http');
const req=http.get('http://127.0.0.1:8088/v1/cdp',{timeout:3000},r=>{
  let d='';r.on('data',c=>d+=c);r.on('end',()=>{
    console.log('CDP_HTTP:'+r.statusCode+'|'+d.substring(0,80));
  });
});
req.on('error',e=>console.log('CDP_FAIL:'+e.message.substring(0,40)));
req.on('timeout',()=>{console.log('CDP_TIMEOUT');req.destroy()});
" 2>&1)
if echo "$CDP_RESULT" | grep -q "^CDP_HTTP:200"; then
    pass "CDP endpoint: ACCESSIBLE on port 8088"
elif echo "$CDP_RESULT" | grep -q "^CDP_HTTP:"; then
    warn "CDP endpoint: responded with HTTP $(echo $CDP_RESULT | cut -d: -f2 | cut -d'|' -f1)"
else
    info "CDP endpoint: NOT DETECTED on port 8088"
fi

echo "--- 9.4 WebSocket Service (port 40005) ---"
WS_RESULT=$(node -e "
const http=require('http');
const req=http.request({hostname:'127.0.0.1',port:40005,method:'GET',path:'/',timeout:3000,headers:{
  'Upgrade':'websocket','Connection':'Upgrade','Sec-WebSocket-Key':'dGhlIHNhbXBsZSBub25jZQ==','Sec-WebSocket-Version':'13'
}},r=>{
  let d='';r.on('data',c=>d+=c);r.on('end',()=>{
    if(r.statusCode===101) console.log('WS_UPGRADE:101');
    else console.log('WS_HTTP:'+r.statusCode+'|'+d.substring(0,60));
  });
});
req.on('error',e=>console.log('WS_FAIL:'+e.message.substring(0,40)));
req.on('timeout',()=>{console.log('WS_TIMEOUT');req.destroy()});
req.end();
" 2>&1)
if echo "$WS_RESULT" | grep -q "^WS_UPGRADE:"; then
    pass "WebSocket service: UPGRADE SUCCESS on port 40005"
elif echo "$WS_RESULT" | grep -q "^WS_HTTP:"; then
    warn "WebSocket port 40005: HTTP response (not upgrading, status $(echo $WS_RESULT | cut -d: -f2 | cut -d'|' -f1))"
else
    info "WebSocket service: NOT DETECTED on port 40005"
fi

echo "--- 9.5 Proxy Auth Detection (ports 18080/18081) ---"
for PPORT in 18080 18081; do
    PROXY_RESULT=$(node -e "
const http=require('http');
const req=http.request({hostname:'127.0.0.1',port:$PPORT,method:'CONNECT',path:'httpbin.org:443',timeout:3000},r=>{
  let d='';r.on('data',c=>d+=c);r.on('end',()=>{
    console.log('PROXY_HTTP:'+r.statusCode);
  });
});
req.on('error',e=>console.log('PROXY_FAIL:'+e.message.substring(0,40)));
req.on('timeout',()=>{console.log('PROXY_TIMEOUT');req.destroy()});
req.end();
" 2>&1)
    if echo "$PROXY_RESULT" | grep -q "^PROXY_HTTP:407"; then
        pass "Proxy port $PPORT: 407 Proxy Authentication Required (proxy detected)"
    elif echo "$PROXY_RESULT" | grep -q "^PROXY_HTTP:"; then
        info "Proxy port $PPORT: HTTP $(echo $PROXY_RESULT | cut -d: -f2)"
    else
        info "Proxy port $PPORT: NOT DETECTED"
    fi
done

echo "--- 9.6 Supervisor Process Manager ---"
if [ -f /app/supervisord.conf ]; then
    pass "Supervisor config: FOUND at /app/supervisord.conf"
    info "  Contents preview: $(head -5 /app/supervisord.conf 2>/dev/null | tr '\n' ' ')"
else
    info "Supervisor config: /app/supervisord.conf NOT FOUND"
fi

if [ -S /run/supervisor.sock ]; then
    pass "Supervisor socket: /run/supervisor.sock EXISTS"
    SUP_CTL=$(which supervisorctl 2>/dev/null)
    if [ -n "$SUP_CTL" ]; then
        SUP_STATUS=$(timeout 3 supervisorctl -s unix:///run/supervisor.sock status 2>&1 | head -10)
        if [ -n "$SUP_STATUS" ]; then
            info "Supervisor status: $SUP_STATUS"
        else
            warn "supervisorctl: no output"
        fi
    else
        info "supervisorctl: NOT INSTALLED"
    fi
elif [ -f /run/supervisor.sock ]; then
    warn "Supervisor socket: /run/supervisor.sock exists but not a socket"
else
    info "Supervisor socket: /run/supervisor.sock NOT FOUND"
fi

echo "--- 9.7 Kubernetes Environment ---"
K8S_HOST="${KUBERNETES_SERVICE_HOST:-}"
K8S_PORT="${KUBERNETES_SERVICE_PORT:-}"
if [ -n "$K8S_HOST" ]; then
    pass "Kubernetes: DETECTED (KUBERNETES_SERVICE_HOST=$K8S_HOST)"
    info "Kubernetes service port: $K8S_PORT"
else
    info "Kubernetes: NOT DETECTED (no KUBERNETES_SERVICE_HOST env)"
fi

for kvar in KUBERNETES_SERVICE_HOST KUBERNETES_SERVICE_PORT KUBERNETES_PORT KUBERNETES_PORT_443_TCP KUBERNETES_PORT_443_TCP_ADDR KUBERNETES_PORT_443_TCP_PORT KUBERNETES_PORT_443_TCP_PROTO KUBERNETES_SERVICE_PORT_HTTPS KUBERNETES_SERVICE_HOST; do
    val="${!kvar}"
    [ -n "$val" ] && info "  $kvar=$val"
done

if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
    pass "Kubernetes service account token: FOUND"
else
    info "Kubernetes service account token: NOT FOUND"
fi

echo "--- 9.8 Node.js Preload Module ---"
if [ -f /app/mcp_proxy_bootstrap/preload.cjs ]; then
    pass "Node.js preload module: FOUND at /app/mcp_proxy_bootstrap/preload.cjs"
    PRELOAD_SIZE=$(wc -c < /app/mcp_proxy_bootstrap/preload.cjs 2>/dev/null)
    info "  File size: ${PRELOAD_SIZE:-unknown} bytes"
    PRELOAD_HEAD=$(head -10 /app/mcp_proxy_bootstrap/preload.cjs 2>/dev/null | tr '\n' ' ')
    info "  Preview: ${PRELOAD_HEAD:-unable to read}"
else
    info "Node.js preload module: /app/mcp_proxy_bootstrap/preload.cjs NOT FOUND"
fi

NODE_PRELOAD=$(node -e 'console.log(process.execArgv.filter(a=>a.includes("require")||a.includes("preload")).join(" ")||"NONE")' 2>&1)
if [ "$NODE_PRELOAD" != "NONE" ] && [ -n "$NODE_PRELOAD" ]; then
    pass "Node.js preload args: $NODE_PRELOAD"
else
    info "Node.js preload args: NONE DETECTED"
fi

echo "--- 9.9 Port Service Mapping ---"
info "Known port-to-service mapping:"
declare -A PORT_MAP=(
    [22]="SSH"
    [3000]="Dev Server"
    [4000]="Preview Server"
    [5900]="VNC"
    [8080]="HTTP Alt"
    [8088]="CDP Proxy"
    [9222]="Chrome DevTools"
    [40005]="WebSocket"
    [18080]="Proxy Auth"
    [18081]="Proxy Auth Alt"
    [443]="HTTPS"
    [80]="HTTP"
    [6379]="Redis"
    [5432]="PostgreSQL"
    [9090]="Prometheus"
    [8443]="HTTPS Alt"
    [3001]="Dev Server Alt"
)
for p in $(echo "${!PORT_MAP[@]}" | tr ' ' '\n' | sort -n); do
    PORT_STATUS=$(node -e "
const net=require('net');
const s=net.createConnection({host:'127.0.0.1',port:$p,timeout:1000},()=>{
  console.log('OPEN');s.destroy();
});
s.on('error',()=>console.log('CLOSED'));
s.on('timeout',()=>{console.log('TIMEOUT');s.destroy()});
" 2>&1)
    case "$PORT_STATUS" in
        OPEN) pass "  Port $p (${PORT_MAP[$p]}): OPEN" ;;
        CLOSED) info "  Port $p (${PORT_MAP[$p]}): CLOSED" ;;
        TIMEOUT) info "  Port $p (${PORT_MAP[$p]}): TIMEOUT" ;;
    esac
done

# ============================================================
# DOMAIN 10: SECURITY & ISOLATION
# ============================================================
section "10" "SECURITY & ISOLATION"

echo "--- 10.1 seccomp Status ---"
SECCOMP_LINE=$(grep "^Seccomp:" /proc/1/status 2>/dev/null)
if [ -n "$SECCOMP_LINE" ]; then
    SECCOMP_VAL=$(echo "$SECCOMP_LINE" | awk '{print $2}')
    case "$SECCOMP_VAL" in
        0) pass "seccomp: DISABLED (no filtering)" ;;
        1) warn "seccomp: STRICT (only allowlist syscalls)" ;;
        2) warn "seccomp: FILTERED (seccomp-bpf active)" ;;
        *) info "seccomp: unknown value $SECCOMP_VAL" ;;
    esac
    info "  Raw: $SECCOMP_LINE"
else
    info "seccomp: cannot read /proc/1/status"
fi

echo "--- 10.2 AppArmor Profile ---"
APPARMOR_VAL=$(cat /proc/1/attr/current 2>/dev/null)
if [ -n "$APPARMOR_VAL" ]; then
    case "$APPARMOR_VAL" in
        unconfined) pass "AppArmor: UNCONFINED (no restrictions)" ;;
        "") info "AppArmor: empty value (may not be available)" ;;
        *) warn "AppArmor: profile=$APPARMOR_VAL" ;;
    esac
else
    info "AppArmor: cannot read /proc/1/attr/current"
fi

if [ -d /sys/kernel/security/apparmor ]; then
    info "AppArmor: securityfs directory exists"
else
    info "AppArmor: securityfs directory NOT FOUND"
fi

echo "--- 10.3 Linux Capabilities Breakdown ---"
CAP_EFF=$(grep "^CapEff:" /proc/1/status 2>/dev/null | awk '{print $2}')
if [ -n "$CAP_EFF" ]; then
    info "CapEff raw: $CAP_EFF"
    CAP_DECODE=$(node -e "
const capHex='$CAP_EFF';
const caps={
  0:'CAP_CHOWN',1:'CAP_DAC_OVERRIDE',2:'CAP_DAC_READ_SEARCH',3:'CAP_FOWNER',
  4:'CAP_FSETID',5:'CAP_KILL',6:'CAP_SETGID',7:'CAP_SETUID',
  8:'CAP_SETPCAP',9:'CAP_LINUX_IMMUTABLE',10:'CAP_NET_BIND_SERVICE',11:'CAP_NET_BROADCAST',
  12:'CAP_NET_ADMIN',13:'CAP_NET_RAW',14:'CAP_IPC_LOCK',15:'CAP_IPC_OWNER',
  16:'CAP_SYS_MODULE',17:'CAP_SYS_RAWIO',18:'CAP_SYS_CHROOT',19:'CAP_SYS_PTRACE',
  20:'CAP_SYS_PACCT',21:'CAP_SYS_ADMIN',22:'CAP_SYS_BOOT',23:'CAP_SYS_NICE',
  24:'CAP_SYS_RESOURCE',25:'CAP_SYS_TIME',26:'CAP_SYS_TTY_CONFIG',27:'CAP_MKNOD',
  28:'CAP_LEASE',29:'CAP_AUDIT_WRITE',30:'CAP_AUDIT_CONTROL',31:'CAP_SETFCAP',
  32:'CAP_MAC_OVERRIDE',33:'CAP_MAC_ADMIN',34:'CAP_SYSLOG',35:'CAP_WAKE_ALARM',
  36:'CAP_BLOCK_SUSPEND',37:'CAP_AUDIT_READ',38:'CAP_PERFMON',39:'CAP_BPF',
  40:'CAP_CHECKPOINT_RESTORE'
};
try{
  const big=BigInt('0x'+capHex);
  const present=[];
  for(let i=0;i<=40;i++){
    if(big&(1n<<BigInt(i))) present.push(caps[i]||'CAP_'+i);
  }
  console.log('CAP_COUNT:'+present.length);
  present.forEach(c=>console.log('CAP:'+c));
}catch(e){console.log('CAP_ERR:'+e.message.substring(0,40))}
" 2>&1)
    CAP_COUNT=$(echo "$CAP_DECODE" | grep "^CAP_COUNT:" | cut -d: -f2)
    info "Effective capabilities count: ${CAP_COUNT:-unknown}"
    echo "$CAP_DECODE" | grep "^CAP:" | while read line; do
        cap_name=$(echo "$line" | cut -d: -f2)
        case "$cap_name" in
            CAP_SYS_ADMIN) warn "  $cap_name: PRESENT (very powerful)" ;;
            CAP_SYS_PTRACE) warn "  $cap_name: PRESENT (can inspect processes)" ;;
            CAP_NET_ADMIN) warn "  $cap_name: PRESENT (network admin)" ;;
            CAP_SYS_RAWIO) warn "  $cap_name: PRESENT (raw I/O access)" ;;
            CAP_SYS_MODULE) warn "  $cap_name: PRESENT (can load kernel modules)" ;;
            CAP_SYS_BOOT) warn "  $cap_name: PRESENT (can reboot)" ;;
            *) pass "  $cap_name: PRESENT" ;;
        esac
    done
else
    info "Capabilities: cannot read CapEff from /proc/1/status"
fi

echo "--- 10.4 Container Runtime Detection ---"
if [ -f /.dockerenv ]; then
    pass "Container: Docker environment detected (/.dockerenv exists)"
else
    info "Container: /.dockerenv NOT FOUND"
fi

if [ -f /run/.containerenv ]; then
    pass "Container: Podman environment detected (/run/.containerenv exists)"
else
    info "Container: /run/.containerenv NOT FOUND"
fi

if [ -f /proc/1/cgroup ]; then
    CGROUP_INFO=$(cat /proc/1/cgroup 2>/dev/null)
    if echo "$CGROUP_INFO" | grep -qi "docker"; then
        pass "Container runtime: Docker (from cgroup)"
    elif echo "$CGROUP_INFO" | grep -qi "kubepods"; then
        pass "Container runtime: Kubernetes (from cgroup)"
    elif echo "$CGROUP_INFO" | grep -qi "containerd"; then
        pass "Container runtime: containerd (from cgroup)"
    elif echo "$CGROUP_INFO" | grep -qi "lxc"; then
        pass "Container runtime: LXC (from cgroup)"
    else
        info "Container cgroup info: $(echo "$CGROUP_INFO" | head -3 | tr '\n' ' ')"
    fi
else
    info "Container: cannot read /proc/1/cgroup"
fi

RUNTIME_DETECT=$(node -e "
const fs=require('fs');
const indicators=[];
try{fs.accessSync('/.dockerenv');indicators.push('dockerenv')}catch(e){}
try{fs.accessSync('/run/.containerenv');indicators.push('containerenv')}catch(e){}
try{const c=fs.readFileSync('/proc/1/cgroup','utf8');if(c.includes('docker'))indicators.push('cgroup:docker');if(c.includes('kubepods'))indicators.push('cgroup:k8s');if(c.includes('containerd'))indicators.push('cgroup:containerd')}catch(e){}
try{const m=fs.readFileSync('/proc/1/mountinfo','utf8');if(m.includes('overlay'))indicators.push('mount:overlay');if(m.includes('aufs'))indicators.push('mount:aufs')}catch(e){}
if(indicators.length===0)console.log('RUNTIME:none');
else console.log('RUNTIME:'+indicators.join(','));
" 2>&1)
if echo "$RUNTIME_DETECT" | grep -q "^RUNTIME:"; then
    info "Container indicators: $(echo $RUNTIME_DETECT | cut -d: -f2-)"
else
    info "Container indicators: none detected (may be bare metal)"
fi

echo "--- 10.5 Syscall Availability ---"
if which strace &>/dev/null; then
    SYSCALLS="write read open close fork execve clone mmap mprotect munmap socket bind listen accept connect pipe dup2 chroot pivot_root mount umount reboot"
    for sc in $SYSCALLS; do
        STRACE_OUT=$(timeout 3 strace -e trace=$sc echo test 2>&1)
        if echo "$STRACE_OUT" | grep -q "$sc("; then
            pass "syscall $sc: AVAILABLE"
        else
            fail "syscall $sc: BLOCKED or UNAVAILABLE"
        fi
    done
else
    info "strace: NOT INSTALLED, testing syscalls via Node.js"
    SYSCALL_NODE=$(node -e "
const{spawn}=require('child_process');
const tests=[
  ['fork',['-c','const{fork}=require(\"child_process\");console.log(\"fork:OK\")']],
  ['exec',['-c','const{execSync}=require(\"child_process\");execSync(\"echo test\");console.log(\"exec:OK\")']],
  ['socket',['-e','const net=require(\"net\");const s=net.createServer();s.listen(0,()=>{console.log(\"socket:OK\");s.close()})']],
];
let done=0;
tests.forEach(([name,args])=>{
  const p=spawn('node',args,{timeout:5000});
  let out='';
  p.stdout.on('data',d=>out+=d);
  p.stderr.on('data',d=>out+=d);
  p.on('close',()=>{
    if(out.includes('OK'))console.log('SYSCALL_OK:'+name);
    else console.log('SYSCALL_FAIL:'+name+'|'+out.substring(0,40).replace(/\\n/g,' '));
    done++;
    if(done===tests.length)process.exit(0);
  });
});
setTimeout(()=>process.exit(0),10000);
" 2>&1)
    echo "$SYSCALL_NODE" | grep "^SYSCALL_" | while read line; do
        sc_name=$(echo "$line" | cut -d: -f2 | cut -d'|' -f1)
        case "$line" in
            SYSCALL_OK:*) pass "syscall $sc_name: AVAILABLE (via Node.js)" ;;
            SYSCALL_FAIL:*) fail "syscall $sc_name: BLOCKED" ;;
        esac
    done
fi

echo "--- 10.6 Node.js Built-in Capabilities ---"
NODE_CAPS=$(node -e "
const coreModules=[
  'assert','buffer','child_process','cluster','console','constants','crypto',
  'dgram','dns','domain','events','fs','http','https','net','os','path',
  'perf_hooks','process','punycode','querystring','readline','repl',
  'stream','string_decoder','sys','timers','tls','tty','url','util',
  'v8','vm','worker_threads','zlib'
];
let available=0;
const results=[];
coreModules.forEach(m=>{
  try{require(m);available++;results.push('MOD_OK:'+m)}
  catch(e){results.push('MOD_FAIL:'+m+'|'+e.message.substring(0,30))}
});
console.log('CORE_COUNT:'+available+'/'+coreModules.length);
results.forEach(r=>console.log(r));

try{
  const crypto=require('crypto');
  const hashes=crypto.getHashes();
  console.log('HASH_COUNT:'+hashes.length);
  console.log('HASHES:'+hashes.join(','));
}catch(e){console.log('HASH_ERR:'+e.message.substring(0,40))}

try{
  const{webcrypto}=require('crypto');
  console.log('WEBCRYPTO:OK');
}catch(e){console.log('WEBCRYPTO:FAIL')}

try{
  const{Worker}=require('worker_threads');
  console.log('WORKER_THREADS:OK');
}catch(e){console.log('WORKER_THREADS:FAIL')}

try{
  new WebSocket('ws://127.0.0.1:1');
  console.log('NATIVE_WS:OK');
}catch(e){
  if(e.message.includes('WebSocket'))console.log('NATIVE_WS:OK');
  else console.log('NATIVE_WS:FAIL');
}
" 2>&1)

CORE_COUNT=$(echo "$NODE_CAPS" | grep "^CORE_COUNT:" | cut -d: -f2)
info "Node.js core modules available: ${CORE_COUNT:-unknown}"

echo "$NODE_CAPS" | grep "^MOD_FAIL:" | while read line; do
    mod_name=$(echo "$line" | cut -d: -f2 | cut -d'|' -f1)
    fail "  Core module $mod_name: UNAVAILABLE"
done

HASH_COUNT=$(echo "$NODE_CAPS" | grep "^HASH_COUNT:" | cut -d: -f2)
if [ -n "$HASH_COUNT" ]; then
    pass "Crypto algorithms: $HASH_COUNT available"
    HASHES=$(echo "$NODE_CAPS" | grep "^HASHES:" | cut -d: -f2-)
    [ -n "$HASHES" ] && info "  Algorithms: $HASHES"
fi

WEBCRYPTO=$(echo "$NODE_CAPS" | grep "^WEBCRYPTO:" | cut -d: -f2)
if [ "$WEBCRYPTO" = "OK" ]; then
    pass "WebCrypto API: AVAILABLE"
else
    fail "WebCrypto API: NOT AVAILABLE"
fi

WORKER=$(echo "$NODE_CAPS" | grep "^WORKER_THREADS:" | cut -d: -f2)
if [ "$WORKER" = "OK" ]; then
    pass "worker_threads: AVAILABLE"
else
    fail "worker_threads: NOT AVAILABLE"
fi

NATIVE_WS=$(echo "$NODE_CAPS" | grep "^NATIVE_WS:" | cut -d: -f2)
if [ "$NATIVE_WS" = "OK" ]; then
    pass "Native WebSocket: AVAILABLE"
else
    info "Native WebSocket: NOT AVAILABLE (may need ws package)"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   RECONNAISSANCE COMPLETE                            ║"
echo "╚═══════════════════════════════════════════════════════╝"

PASS_COUNT=$(grep -c "^PASS|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)
FAIL_COUNT=$(grep -c "^FAIL|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)
WARN_COUNT=$(grep -c "^WARN|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)
INFO_COUNT=$(grep -c "^INFO|" "$RECON_DIR/results.txt" 2>/dev/null || echo 0)

echo ""
echo "Results Summary:"
echo "  ✅ PASS: $PASS_COUNT"
echo "  ❌ FAIL: $FAIL_COUNT"
echo "  ⚠️  WARN: $WARN_COUNT"
echo "  ℹ️  INFO: $INFO_COUNT"
echo ""
echo "Full results saved to: $RECON_DIR/results.txt"
echo ""
echo "Next steps:"
echo "  1. Review FAIL items for P0/P1 blockers"
echo "  2. Run fix-network.js for network issues"
echo "  3. Run setup-dev-toolchain.sh for missing tools"
echo "  4. Run verify-env.sh for full validation"
