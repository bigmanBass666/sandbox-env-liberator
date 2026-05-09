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

# === Save npm config ===
NPMRC="/root/.npmrc"
if [ ! -f "$NPMRC" ]; then
    touch "$NPMRC"
    fix "Created empty .npmrc"
fi

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
