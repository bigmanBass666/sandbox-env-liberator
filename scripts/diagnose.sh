#!/bin/bash
# Sandbox Environment Diagnostic Tool
# Run this to understand your current environment constraints

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "[INFO] $1"; }

echo "========================================="
echo "  SANDBOX ENVIRONMENT DIAGNOSTIC REPORT"
echo "========================================="
echo ""

# === OS Info ===
echo "--- System Information ---"
uname -a 2>/dev/null || warn "Cannot get system info"
cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION|ID)=" | head -3 || warn "No os-release"
echo ""

# === Browser Detection ===
echo "--- Browser Availability ---"

GOOGLE_CHROME="/opt/google/chrome/chrome"
PW_CHROMIUM=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
PW_HEADLESS=$(find /root/.cache/ms-playwright -name "chrome-headless-shell" -type f 2>/dev/null | head -1)

if [ -f "$GOOGLE_CHROME" ]; then
    pass "Google Chrome found at $GOOGLE_CHROME"
else
    fail "Google Chrome not found"
fi

if [ -n "$PW_CHROMIUM" ]; then
    pass "Playwright Chromium found: $PW_CHROMIUM"
else
    fail "Playwright Chromium not found"
fi

if [ -n "$PW_HEADLESS" ]; then
    pass "Playwright Headless Shell found: $PW_HEADLESS"
else
    warn "Playwright Headless Shell not found"
fi
echo ""

# === Library Check ===
echo "--- Shared Library Status ---"
BROWSER="${PW_CHROMIUM:-$GOOGLE_CHROME}"
if [ -f "$BROWSER" ]; then
    MISSING=$(ldd "$BROWSER" 2>&1 | grep "not found" | awk '{print $1}' | sort -u)
    if [ -z "$MISSING" ]; then
        pass "All shared libraries satisfied for $(basename $BROWSER)"
    else
        COUNT=$(echo "$MISSING" | wc -l)
        fail "$COUNT missing libraries:"
        echo "$MISSING" | sed 's/^/      /'
    fi
else
    warn "Cannot check libs (no browser binary found)"
fi
echo ""

# === Network Test ===
echo "--- Network Connectivity ---"

# Test CLI (curl/wget)
if curl -s --timeout=3 https://httpbin.org/ip -o /dev/null 2>&1; then
    pass "CLI networking (curl): WORKING"
elif wget -q --timeout=3 https://httpbin.org/ip -O /dev/null 2>&1; then
    pass "CLI networking (wget): WORKING"
else
    fail "CLI networking: BLOCKED"
fi

# Test Node.js fetch
NODE_RESULT=$(node -e "
fetch('https://httpbin.org/ip')
  .then(r => r.json())
  .then(d => console.log('OK:' + d.origin))
  .catch(() => console.log('FAIL'))
" 2>&1)

if echo "$NODE_RESULT" | grep -q "^OK:"; then
    IP=$(echo "$NODE_RESULT" | cut -d: -f2)
    pass "Node.js fetch(): WORKING (IP: $IP)"
else
    fail "Node.js fetch(): BLOCKED or ERROR"
fi

# Test Python
PY_RESULT=$(python3 -c "
import urllib.request, ssl
ssl._create_default_https_context = ssl._create_unverified_context
print('OK:' + urllib.request.urlopen('https://httpbin.org/ip', timeout=3).read().decode()[:15])
" 2>&1) && true

if echo "$PY_RESULT" | grep -q "^OK:"; then
    pass "Python urllib: WORKING"
else
    fail "Python urllib: BLOCKED or MISSING"
fi
echo ""

# === Tool Chain ===
echo "--- Tool Chain ---"
for cmd in node npm npx python3 pip playwright google-chrome; do
    if which "$cmd" &>/dev/null; then
        VER=$("$cmd" --version 2>&1 | head -1 || true)
        pass "$cmd: $VER"
    else
        fail "$cmd: NOT FOUND"
    fi
done
echo ""

# === MCP Tools ===
echo "--- MCP / External Tools ---"
info "Chrome DevTools MCP: Requires manual test (mcp_Chrome_DevTools_MCP_list_pages)"
info "WebFetch MCP: Requires manual test (WebFetch tool)"
info "Memory MCP: Requires manual test (mcp_Memory_read_graph)"
echo ""

# === Disk Space ===
echo "--- Resources ---"
DF=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')
pass "Free disk space: $DF"
MEM=$(free -h 2>/dev/null | grep Mem | awk '{print $7}')
pass "Available memory: $MEM"
echo ""

# === Summary ===
echo "========================================="
echo "  DIAGNOSTIC COMPLETE"
echo "========================================="
echo ""
echo "Next steps based on findings:"
echo "  - Missing browser?          -> Install via npm/pip"
echo "  - Missing libraries?        -> Use sandbox-env-setup Skill Phase 2"
echo "  - CLI network blocked?      -> Use Node.js fetch() for downloads"
echo "  - All tools present?        -> Environment is ready!"
