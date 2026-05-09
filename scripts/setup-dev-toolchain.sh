#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fix() { echo -e "${CYAN}[FIX]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   DEVELOPMENT TOOLCHAIN SETUP                        ║"
echo "╚═══════════════════════════════════════════════════════╝"

# === Browser & Playwright ===
echo ""
echo "--- Browser & Playwright ---"
PW_CHROME=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
if [ -n "$PW_CHROME" ]; then
    MISSING=$(ldd "$PW_CHROME" 2>&1 | grep "not found" | awk '{print $1}' | sort -u)
    if [ -z "$MISSING" ]; then
        pass "Browser ready: $($PW_CHROME --version 2>&1 | head -1)"
    else
        warn "Browser has missing libs, running fix-network.js..."
        node /workspace/sandbox-env-setup/scripts/fix-network.js 2>&1 | tail -5
    fi
else
    fix "Installing Playwright Chromium..."
    npm install -g playwright 2>/dev/null
    npx playwright install chromium 2>&1 | tail -3
fi

PW_MOD=$(node -e "try{require('playwright');console.log('OK')}catch{console.log('NO')}" 2>/dev/null)
if [ "$PW_MOD" = "OK" ]; then
    pass "Playwright module: AVAILABLE"
else
    fix "Installing Playwright npm package..."
    npm install -g playwright 2>/dev/null
fi

# === Terminal Multiplexers ===
echo ""
echo "--- Terminal Multiplexers ---"
for cmd in screen tmux; do
    if ! which $cmd &>/dev/null; then
        fix "Installing $cmd..."
        apt-get install -y $cmd 2>/dev/null && pass "$cmd installed" || warn "$cmd install failed"
    else
        pass "$cmd: already available"
    fi
done

# === Development Databases ===
echo ""
echo "--- Databases ---"
if which sqlite3 &>/dev/null; then
    pass "SQLite3: available"
else
    fix "Installing SQLite3..."
    apt-get install -y sqlite3 2>/dev/null && pass "SQLite3 installed" || warn "SQLite3 install failed"
fi

for db in postgresql redis-server; do
    if which $db &>/dev/null; then
        pass "$db: available"
    else
        info "$db: not installed (available via apt if needed)"
    fi
done

# === Node.js Build Tools ===
echo ""
echo "--- Node.js Build Tools ---"
for pkg in webpack vite esbuild rollup typescript; do
    if npx $pkg --version &>/dev/null 2>&1; then
        pass "$pkg: available via npx"
    else
        fix "Installing $pkg globally..."
        npm install -g $pkg 2>/dev/null && pass "$pkg installed" || warn "$pkg install failed"
    fi
done

# === Python Development ===
echo ""
echo "--- Python Development ---"
if which pip3 &>/dev/null || which pip &>/dev/null; then
    PIP=$(which pip3 2>/dev/null || which pip 2>/dev/null)
    pass "pip: available ($PIP)"
    
    for pkg in virtualenv httpx requests beautifulsoup4; do
        if python3 -c "import ${pkg}" 2>/dev/null; then
            pass "Python $pkg: installed"
        else
            fix "Installing Python $pkg..."
            $PIP install --user $pkg 2>/dev/null && pass "$pkg installed" || warn "$pkg install failed"
        fi
    done
else
    warn "pip not available"
fi

# === Go Tools ===
echo ""
echo "--- Go Tools ---"
if which go &>/dev/null; then
    pass "Go: $(go version 2>/dev/null | head -1)"
    for tool in golang.org/x/tools/gopls@latest github.com/go-delve/delve/cmd/dlv@latest; do
        TOOL_NAME=$(basename $tool | sed 's/@.*//')
        if which $TOOL_NAME &>/dev/null; then
            pass "Go $TOOL_NAME: available"
        else
            fix "Installing Go $TOOL_NAME..."
            go install $tool 2>/dev/null && pass "$TOOL_NAME installed" || warn "$TOOL_NAME install failed"
        fi
    done
fi

# === Cloud CLIs (on-demand) ===
echo ""
echo "--- Cloud CLIs (optional) ---"
CLI_INSTALLS="
aws|awscli
gcloud|google-cloud-cli
"
while IFS='|' read -r cmd pkg; do
    [ -z "$cmd" ] && continue
    if which $cmd &>/dev/null; then
        pass "$cmd: available"
    else
        info "$cmd: not installed (install with: apt install $pkg or download binary)"
    fi
done <<< "$CLI_INSTALLS"

# === Container Tools ===
echo ""
echo "--- Container Tools ---"
if which docker &>/dev/null; then
    pass "Docker: available"
else
    info "Docker: not available (Docker-in-Docker not supported in this sandbox)"
    info "  Alternative: use 'docker' CLI to connect to remote Docker hosts"
fi

# === SSH Setup ===
echo ""
echo "--- SSH ---"
if which ssh &>/dev/null; then
    pass "SSH client: available"
    if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
        fix "Generating SSH key pair..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q 2>/dev/null
        pass "SSH key generated: ~/.ssh/id_ed25519"
    else
        pass "SSH keys: exist"
    fi
fi

# === Summary ===
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   TOOLCHAIN SETUP COMPLETE                           ║"
echo "╚═══════════════════════════════════════════════════════╝"
