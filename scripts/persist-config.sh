#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

fix() { echo -e "${CYAN}[CONFIG]${NC} $1"; }
pass() { echo -e "${GREEN}[OK]${NC} $1"; }

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   PERSISTENT CONFIGURATION SETUP                     ║"
echo "╚═══════════════════════════════════════════════════════╝"

SETUP_SCRIPT="/usr/local/bin/sandbox-env-setup.sh"
PROFILE_MARKER="# SANDBOX_ENV_SETUP"

# === Create environment setup script ===
fix "Creating $SETUP_SCRIPT..."
cat > "$SETUP_SCRIPT" << 'ENVEOF'
#!/bin/bash
EXTRACT_LIBS="/tmp/extracted_libs/usr/lib/x86_64-linux-gnu"
if [ -d "$EXTRACT_LIBS" ]; then
    export LD_LIBRARY_PATH="$EXTRACT_LIBS:${LD_LIBRARY_PATH:-}"
fi

PW_CHROME_DIR=$(find /root/.cache/ms-playwright -name "chrome-linux64" -type d 2>/dev/null | head -1)
if [ -n "$PW_CHROME_DIR" ]; then
    export LD_LIBRARY_PATH="$PW_CHROME_DIR:${LD_LIBRARY_PATH:-}"
fi

if [ -d "/root/.local/bin" ]; then
    export PATH="/root/.local/bin:${PATH:-}"
fi

if [ -d "/root/go/bin" ]; then
    export PATH="/root/go/bin:${PATH:-}"
fi

if [ -d "/root/.cargo/bin" ]; then
    export PATH="/root/.cargo/bin:${PATH:-}"
fi

NODE_GLOBAL=$(npm root -g 2>/dev/null)
if [ -n "$NODE_GLOBAL" ]; then
    export NODE_PATH="${NODE_GLOBAL}:${NODE_PATH:-}"
fi

export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/root/.cache/ms-playwright}"
ENVEOF
chmod +x "$SETUP_SCRIPT"
pass "Created $SETUP_SCRIPT"

# === Add to shell profiles ===
for profile in ~/.bashrc ~/.zshrc ~/.profile; do
    if [ -f "$profile" ]; then
        if ! grep -q "$PROFILE_MARKER" "$profile" 2>/dev/null; then
            echo "" >> "$profile"
            echo "$PROFILE_MARKER - auto-generated" >> "$profile"
            echo "if [ -f $SETUP_SCRIPT ]; then" >> "$profile"
            echo "    source $SETUP_SCRIPT" >> "$profile"
            echo "fi" >> "$profile"
            fix "Added sandbox-env-setup to $profile"
        else
            pass "$profile already configured"
        fi
    fi
done

# === Create /etc/profile.d entry (for all users) ===
if [ -d /etc/profile.d ] && [ ! -f /etc/profile.d/sandbox-env.sh ]; then
    cp "$SETUP_SCRIPT" /etc/profile.d/sandbox-env.sh
    fix "Created /etc/profile.d/sandbox-env.sh"
fi

# === Save proxy configuration ===
PROXY_CONF="/root/.config/sandbox-env/proxy.conf"
mkdir -p "$(dirname $PROXY_CONF)"
{
    echo "HTTP_PROXY=${http_proxy:-}"
    echo "HTTPS_PROXY=${https_proxy:-}"
    echo "NO_PROXY=${no_proxy:-}"
} > "$PROXY_CONF"
fix "Saved proxy config to $PROXY_CONF"

# === Save npm config (with mirror) ===
NPMRC="/root/.npmrc"
fix "Configuring npm mirror (npmmirror.com)..."
if [ ! -f "$NPMRC" ] || ! grep -q "npmmirror.com" "$NPMRC" 2>/dev/null; then
    {
        echo "registry=https://registry.npmmirror.com"
        echo "maxsockets=10"
        echo "fetch-retries=3"
        echo "fetch-retry-midletimeout=5000"
        echo "fetch-timeout=30000"
    } > "$NPMRC"
    pass "npm → npmmirror.com"
else
    pass "npm mirror already configured"
fi

# === Configure pip mirror (Tsinghua PyPI) ===
fix "Configuring pip mirror (Tsinghua)..."
PIP_CONF_DIR="/root/.pip"
mkdir -p "$PIP_CONF_DIR"
PIP_CONF="$PIP_CONF_DIR/pip.conf"
if [ ! -f "$PIP_CONF" ] || ! grep -q "tuna.tsinghua.edu.cn" "$PIP_CONF" 2>/dev/null; then
    cat > "$PIP_CONF" << 'PIPEOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 30
retries = 3
PIPEOF
    pass "pip → pypi.tuna.tsinghua.edu.cn"
else
    pass "pip mirror already configured"
fi

# === Configure Go GOPROXY (goproxy.cn) ===
fix "Configuring Go GOPROXY (goproxy.cn)..."
if command -v go &>/dev/null; then
    CURRENT_GOPROXY=$(go env GOPROXY 2>/dev/null)
    if [[ "$CURRENT_GOPROXY" != *"goproxy.cn"* ]]; then
        go env -w GOPROXY=https://goproxy.cn,direct
        pass "Go → goproxy.cn,direct"
    else
        pass "Go GOPROXY already configured"
    fi
else
    fix "Go not installed, skipping"
fi

# === Configure Cargo mirror (rsproxy.cn) ===
fix "Configuring Cargo mirror (rsproxy.cn)..."
CARGO_DIR="/root/.cargo"
mkdir -p "$CARGO_DIR"
CARGO_CONFIG="$CARGO_DIR/config.toml"
if [ ! -f "$CARGO_CONFIG" ] || ! grep -q "rsproxy.cn" "$CARGO_CONFIG" 2>/dev/null; then
    cat > "$CARGO_CONFIG" << 'CARGOEOF'
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[net]
git-fetch-with-cli = true
CARGOEOF
    pass "Cargo → rsproxy.cn (sparse)"
else
    pass "Cargo mirror already configured"
fi

# === Configure apt mirror (Tsinghua Ubuntu) ===
fix "Configuring apt mirror (Tsinghua)..."
APT_MIRROR="/etc/apt/sources.list.d/ubuntu-mirror.list"
if [ ! -f "$APT_MIRROR" ] || ! grep -q "tuna.tsinghua.edu.cn" "$APT_MIRROR" 2>/dev/null; then
    cat > "$APT_MIRROR" << 'APTEOF'
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-security main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-backports main restricted universe multiverse
APTEOF
    pass "apt → mirrors.tuna.tsinghua.edu.cn"
else
    pass "apt mirror already configured"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   MIRROR SOURCES CONFIGURED                         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo "  npm   → registry.npmmirror.com"
echo "  pip   → pypi.tuna.tsinghua.edu.cn/simple"
echo "  Go    → goproxy.cn,direct"
echo "  Cargo → rsproxy.cn (sparse protocol)"
echo "  apt   → mirrors.tuna.tsinghua.edu.cn/ubuntu"

# === Create workspace restore script ===
RESTORE_SCRIPT="/usr/local/bin/sandbox-restore.sh"
cat > "$RESTORE_SCRIPT" << 'RESTOREEOF'
#!/bin/bash
echo "Restoring sandbox environment..."
source /usr/local/bin/sandbox-env-setup.sh

BROWSER=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
if [ -n "$BROWSER" ]; then
    MISSING=$(ldd "$BROWSER" 2>&1 | grep "not found" | awk '{print $1}')
    if [ -n "$MISSING" ]; then
        echo "⚠️  Browser has missing dependencies. Run: node /workspace/sandbox-env-setup/scripts/fix-network.js"
    else
        echo "✅ Browser ready: $($BROWSER --version 2>&1 | head -1)"
    fi
else
    echo "⚠️  No browser installed. Run: npx playwright install chromium"
fi

echo "✅ Environment restored. PATH=$PATH"
RESTOREEOF
chmod +x "$RESTORE_SCRIPT"
fix "Created $RESTORE_SCRIPT"

# === Create startup marker ===
echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > /root/.sandbox-last-setup
pass "Created setup timestamp marker"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   PERSISTENT CONFIG COMPLETE                         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "To restore in a new session:"
echo "  source /usr/local/bin/sandbox-env-setup.sh"
echo "  # Or just start a new shell (auto-sourced from .bashrc/.zshrc)"
