# Domain 5: Browser & GUI

**This is the #1 P0 issue in most sandboxes.** The browser is essential for Playwright MCP, web automation, and many development workflows.

**Complete Browser Setup** (automated by fix-network.js):

```bash
# Step 1: Install Playwright
npm install -g playwright

# Step 2: Install Chromium browser
npx playwright install chromium

# Step 3: Install missing system dependencies
# Option A: apt (preferred when available)
apt-get install -y libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgbm1 libasound2t64 libatk1.0-0 libatk-bridge2.0-0 \
  libatspi2.0-0 libcups2

# Option B: Node.js fetch fallback (when apt is blocked)
node /workspace/sandbox-env-setup/scripts/fix-network.js

# Step 4: Verify
node -e "const{chromium}=require('playwright');(async()=>{const b=await chromium.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});console.log('Browser OK:',await b.version());await b.close()})()"
```

**Common Missing Libraries** (Ubuntu 24.04):
```
libxkbcommon.so.0    → libxkbcommon0
libXcomposite.so.1   → libxcomposite1
libXdamage.so.1      → libxdamage1
libXfixes.so.3       → libxfixes3
libXrandr.so.2       → libxrandr2
libgbm.so.1          → libgbm1
libasound.so.2       → libasound2t64
libatk-1.0.so.0      → libatk1.0-0
libatk-bridge-2.0.so.0 → libatk-bridge2.0-0
libatspi.so.0        → libatspi2.0-0
libcups.so.2         → libcups2
```

**Chrome DevTools MCP**: Port 9222 is typically accessible. The Playwright MCP manages browser lifecycle automatically — do NOT manually launch Chrome with `--remote-debugging-port`.

**If MCP "Target closed" errors occur**: Fall back to Playwright Node.js API directly.

**CDP Browser Connection** (Round 10 discovery — preferred over downloading Chromium):

Chrome 147+ is already running on port 9222 with CDP enabled, managed by the **browser_ctrl** service (port 9090). This eliminates the need to download ~170MB of Chromium binary.

```javascript
// Connect to existing Chrome via CDP — no download required
const { connectCDPBrowser } = require('/workspace/sandbox-env-setup/scripts/fix-network');
const browser = await connectCDPBrowser(); // defaults to http://127.0.0.1:9222

if (browser) {
    const page = browser.contexts()[0].pages()[0] || await browser.contexts()[0].newPage();
    await page.goto('https://example.com');
    // Use browser normally — it's already running!
} else {
    // Fallback: launch local Chromium
    const { chromium } = require('playwright');
    const browser = await chromium.launch({ headless: true });
}
```

Or use Playwright directly:
```javascript
const { chromium } = require('playwright');
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
```

**Key advantages of CDP connection**:
- ✅ Zero download (~170MB saved)
- ✅ Instant connection (browser already warm)
- ✅ Managed by platform's browser_ctrl service (port 9090)
- ✅ Persists across sessions (platform-managed process)
- ⚠️ Browser state is shared — don't close it if other tools are using it

**Verify CDP availability**:
```bash
curl -s http://127.0.0.1:9222/json/version | head -5
# Expected: {"Browser":"Chrome/147.x.x.x","Protocol-Version":"1.3",...}
```
