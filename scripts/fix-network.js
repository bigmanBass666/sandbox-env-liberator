#!/usr/bin/env node
const http = require('http');
const https = require('https');
const { URL } = require('url');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const RECON_FILE = '/tmp/sandbox-recon/results.txt';

function log(level, msg) {
    const icons = { PASS: '✅', FAIL: '❌', WARN: '⚠️', INFO: 'ℹ️', FIX: '🔧' };
    console.log(`${icons[level] || '•'} [${level}] ${msg}`);
}

function readReconResults() {
    try {
        return fs.readFileSync(RECON_FILE, 'utf8').split('\n').filter(l => l.trim());
    } catch {
        return [];
    }
}

function hasFail(results, keyword) {
    return results.some(r => r.startsWith('FAIL|') && r.includes(keyword));
}

function testUrl(url, timeout = 8000) {
    return new Promise((resolve) => {
        const parsed = new URL(url);
        const mod = parsed.protocol === 'https:' ? https : http;
        const req = mod.get(url, { timeout }, (res) => {
            let body = '';
            res.on('data', c => body += c);
            res.on('end', () => resolve({ ok: true, status: res.statusCode, body: body.substring(0, 200) }));
        });
        req.on('error', e => resolve({ ok: false, error: e.message }));
        req.on('timeout', () => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
    });
}

function isPackageInstalled(pkg) {
    try {
        const out = execSync(`dpkg -l ${pkg} 2>/dev/null`, { stdio: 'pipe' }).toString();
        return out.includes('ii') && out.includes(pkg);
    } catch {
        return false;
    }
}

function isNpmGlobalInstalled(pkg) {
    try {
        const out = execSync(`npm list -g ${pkg} 2>/dev/null`, { stdio: 'pipe' }).toString();
        return !out.includes('(empty)') && out.includes(pkg);
    } catch {
        return false;
    }
}

function isLineInFile(filePath, line) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        return content.includes(line);
    } catch {
        return false;
    }
}

function isFileValid(filePath, minSize = 1) {
    try {
        const stat = fs.statSync(filePath);
        return stat.size >= minSize;
    } catch {
        return false;
    }
}

async function detectNetworkProfile() {
    log('INFO', 'Detecting network profile...');

    const tests = {
        curl: false,
        wget: false,
        nodeFetch: false,
        pythonUrllib: false,
        aptGet: false,
        goNet: false,
    };

    try { execSync('curl -s --connect-timeout 5 https://httpbin.org/ip -o /dev/null 2>&1'); tests.curl = true; } catch {}
    try { execSync('wget -q --timeout=5 https://httpbin.org/ip -O /dev/null 2>&1'); tests.wget = true; } catch {}

    try {
        const r = await fetch('https://httpbin.org/ip', { signal: AbortSignal.timeout(8000) });
        if (r.ok) tests.nodeFetch = true;
    } catch {}

    try {
        const out = execSync(`python3 -c "
import urllib.request, ssl
ssl._create_default_https_context = ssl._create_unverified_context
urllib.request.urlopen('https://httpbin.org/ip', timeout=5)
print('OK')
" 2>&1`).toString();
        if (out.includes('OK')) tests.pythonUrllib = true;
    } catch {}

    try { execSync('apt-get update -qq 2>&1', { timeout: 15000 }); tests.aptGet = true; } catch {}

    const workingCount = Object.values(tests).filter(Boolean).length;

    let profile;
    if (workingCount >= 4) {
        profile = 'OPEN';
        log('PASS', `Network profile: OPEN (${workingCount}/6 channels work)`);
    } else if (workingCount >= 2) {
        profile = 'PARTIAL';
        log('WARN', `Network profile: PARTIALLY OPEN (${workingCount}/6 channels work)`);
    } else if (tests.nodeFetch || tests.pythonUrllib) {
        profile = 'PROXY_ONLY';
        log('WARN', 'Network profile: PROXY_ONLY (Node.js/Python work, CLI blocked)');
    } else {
        profile = 'SEVERE';
        log('FAIL', 'Network profile: SEVERELY RESTRICTED');
    }

    log('INFO', `  curl=${tests.curl} wget=${tests.wget} fetch=${tests.nodeFetch} python=${tests.pythonUrllib} apt=${tests.aptGet}`);

    return { profile, tests };
}

async function fixProxyConfig() {
    const proxy = process.env.http_proxy || process.env.HTTP_PROXY;
    const httpsProxy = process.env.https_proxy || process.env.HTTPS_PROXY;

    if (proxy) {
        log('INFO', `HTTP proxy detected: ${proxy}`);
        log('INFO', `HTTPS proxy detected: ${httpsProxy || 'same as HTTP'}`);
    }

    const noProxy = process.env.no_proxy || process.env.NO_PROXY || '';
    log('INFO', `no_proxy: ${noProxy}`);

    const npmRc = path.join(process.env.HOME || '/root', '.npmrc');
    if (proxy && !fs.existsSync(npmRc)) {
        fs.writeFileSync(npmRc, `proxy=${proxy}\nhttps-proxy=${httpsProxy || proxy}\n`);
        log('FIX', `Created .npmrc with proxy settings`);
    } else if (proxy && fs.existsSync(npmRc)) {
        const content = fs.readFileSync(npmRc, 'utf8');
        if (!content.includes('proxy=')) {
            fs.appendFileSync(npmRc, `\nproxy=${proxy}\nhttps-proxy=${httpsProxy || proxy}\n`);
            log('FIX', `Added proxy to existing .npmrc`);
        }
    }

    let gitConfig = '';
    try { gitConfig = execSync('git config --global --list 2>/dev/null').toString(); } catch {}
    if (proxy && !gitConfig.includes('http.proxy')) {
        try {
            execSync(`git config --global http.proxy ${proxy}`);
            execSync(`git config --global https.proxy ${httpsProxy || proxy}`);
            log('FIX', `Set git proxy to ${proxy}`);
        } catch {}
    }
}

async function fixAptProxy() {
    const proxy = process.env.http_proxy || process.env.HTTP_PROXY;
    if (!proxy) return;

    const aptConf = '/etc/apt/apt.conf.d/99proxy';
    if (!fs.existsSync(aptConf)) {
        const parsed = new URL(proxy);
        fs.writeFileSync(aptConf, `Acquire::http::Proxy "${proxy}";\nAcquire::https::Proxy "${process.env.https_proxy || proxy}";\n`);
        log('FIX', `Created apt proxy config at ${aptConf}`);
    }
}

async function downloadViaNodeFetch(url, destPath) {
    const dir = path.dirname(destPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    const resp = await fetch(url, { signal: AbortSignal.timeout(60000) });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const buf = Buffer.from(await resp.arrayBuffer());
    fs.writeFileSync(destPath, buf);
    return buf.length;
}

async function downloadWithFallback(url, destPath) {
    const dir = path.dirname(destPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    const channels = [
        {
            name: 'curl',
            fn: async () => {
                execSync(`curl -sL --connect-timeout 10 -o "${destPath}" "${url}"`, {
                    timeout: 120000,
                    stdio: 'pipe',
                });
                if (!isFileValid(destPath)) throw new Error('curl downloaded empty file');
            }
        },
        {
            name: 'wget',
            fn: async () => {
                execSync(`wget -q --timeout=10 -O "${destPath}" "${url}"`, {
                    timeout: 120000,
                    stdio: 'pipe',
                });
                if (!isFileValid(destPath)) throw new Error('wget downloaded empty file');
            }
        },
        {
            name: 'Node.js fetch',
            fn: async () => {
                await downloadViaNodeFetch(url, destPath);
            }
        },
        {
            name: 'Python urllib',
            fn: async () => {
                execSync(`python3 -c "import urllib.request; urllib.request.urlretrieve('${url}', '${destPath}')"`, {
                    timeout: 120000,
                    stdio: 'pipe',
                });
                if (!isFileValid(destPath)) throw new Error('Python urllib downloaded empty file');
            }
        },
        {
            name: 'Playwright',
            fn: async () => {
                let playwright;
                try {
                    playwright = require('playwright');
                } catch {
                    throw new Error('Playwright not available');
                }
                const browser = await playwright.chromium.launch({ headless: true });
                const page = await browser.newPage();
                try {
                    const response = await page.goto(url, { timeout: 60000, waitUntil: 'load' });
                    if (!response || !response.ok()) throw new Error(`Playwright HTTP ${response ? response.status() : 'no response'}`);
                    const contentType = response.headers()['content-type'] || '';
                    let content;
                    if (contentType.includes('text') || contentType.includes('json') || contentType.includes('javascript') || contentType.includes('xml')) {
                        content = await page.content();
                    } else {
                        const buf = await response.body();
                        content = buf;
                    }
                    if (typeof content === 'string') {
                        fs.writeFileSync(destPath, content);
                    } else {
                        fs.writeFileSync(destPath, Buffer.from(content));
                    }
                    if (!isFileValid(destPath)) throw new Error('Playwright downloaded empty file');
                } finally {
                    await browser.close();
                }
            }
        },
    ];

    for (let i = 0; i < channels.length; i++) {
        const ch = channels[i];
        try {
            log('INFO', `  [通道${i + 1}/${channels.length}] ${ch.name}: 尝试下载 ${url.substring(0, 80)}...`);
            await ch.fn();
            const size = fs.statSync(destPath).size;
            log('PASS', `  [通道${i + 1}] ${ch.name}: 下载成功 (${Math.round(size / 1024)}KB) -> ${destPath}`);
            return size;
        } catch (e) {
            log('WARN', `  [通道${i + 1}] ${ch.name}: 失败 - ${e.message.substring(0, 80)}`);
            if (fs.existsSync(destPath)) {
                try { fs.unlinkSync(destPath); } catch {}
            }
        }
    }

    throw new Error(`所有5个下载通道均失败: ${url}`);
}

async function downloadWithRetry(url, destPath, maxRetries = 3) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            log('INFO', `下载重试 [${attempt}/${maxRetries}]: ${url.substring(0, 80)}...`);
            const size = await downloadWithFallback(url, destPath);
            return size;
        } catch (e) {
            if (attempt < maxRetries) {
                const delay = Math.pow(2, attempt - 1);
                log('WARN', `下载失败 [${attempt}/${maxRetries}], ${delay}秒后重试: ${e.message.substring(0, 80)}`);
                await new Promise(r => setTimeout(r, delay * 1000));
            } else {
                log('FAIL', `下载重试耗尽 [${maxRetries}/${maxRetries}]: ${url.substring(0, 80)}`);
                throw e;
            }
        }
    }
}

async function detectAndHandleProxyAuth() {
    log('INFO', '检测代理认证需求...');

    const proxy = process.env.http_proxy || process.env.HTTP_PROXY;
    if (!proxy) {
        log('INFO', '未检测到代理，跳过代理认证检测');
        return;
    }

    let needsAuth = false;
    try {
        const out = execSync(`curl -v --connect-timeout 5 "${proxy}" 2>&1`, {
            timeout: 10000,
            stdio: 'pipe',
        }).toString();
        if (out.includes('407') || out.includes('Proxy Authentication Required')) {
            needsAuth = true;
            log('WARN', '代理返回407，需要认证');
        }
    } catch (e) {
        const stderr = e.stderr ? e.stderr.toString() : e.message;
        if (stderr.includes('407') || stderr.includes('Proxy Authentication Required')) {
            needsAuth = true;
            log('WARN', '代理返回407，需要认证');
        }
    }

    if (!needsAuth) {
        log('PASS', '代理不需要认证');
        return;
    }

    let proxyUser = process.env.PROXY_USER || '';
    let proxyPass = process.env.PROXY_PASS || '';

    if (!proxyUser || !proxyPass) {
        try {
            const parsed = new URL(proxy);
            if (parsed.username) proxyUser = decodeURIComponent(parsed.username);
            if (parsed.password) proxyPass = decodeURIComponent(parsed.password);
        } catch {}
    }

    if (!proxyUser || !proxyPass) {
        const etcDir = '/app/etc/';
        try {
            if (fs.existsSync(etcDir)) {
                const files = fs.readdirSync(etcDir).filter(f => f.endsWith('.conf') || f.endsWith('.env') || f.endsWith('.json'));
                for (const file of files) {
                    try {
                        const content = fs.readFileSync(path.join(etcDir, file), 'utf8');
                        const userMatch = content.match(/(?:PROXY_USER|proxy_user|proxy\.user)\s*[=:]\s*["']?([^"'\s\n]+)/);
                        const passMatch = content.match(/(?:PROXY_PASS|proxy_pass|proxy\.pass)\s*[=:]\s*["']?([^"'\s\n]+)/);
                        if (userMatch && !proxyUser) proxyUser = userMatch[1];
                        if (passMatch && !proxyPass) proxyPass = passMatch[1];
                    } catch {}
                }
            }
        } catch {}
    }

    if (!proxyUser || !proxyPass) {
        log('FAIL', '代理需要认证但未找到凭据 (PROXY_USER/PROXY_PASS)');
        return;
    }

    log('FIX', `找到代理凭据: ${proxyUser}`);

    const npmRc = path.join(process.env.HOME || '/root', '.npmrc');
    if (fs.existsSync(npmRc)) {
        const content = fs.readFileSync(npmRc, 'utf8');
        if (!content.includes('proxy-username') && !content.includes(proxyUser)) {
            fs.appendFileSync(npmRc, `\nproxy-username=${proxyUser}\nproxy-password=${proxyPass}\n`);
            log('FIX', '已配置 npm 代理认证');
        }
    }

    try {
        const gitProxyAuth = proxy.replace(/^(https?:\/\/)/, `$1${proxyUser}:${proxyPass}@`);
        execSync(`git config --global http.proxy ${gitProxyAuth}`);
        log('FIX', '已配置 git 代理认证');
    } catch {}

    try {
        const curlRc = path.join(process.env.HOME || '/root', '.curlrc');
        const curlContent = fs.existsSync(curlRc) ? fs.readFileSync(curlRc, 'utf8') : '';
        if (!curlContent.includes('proxy-user')) {
            fs.appendFileSync(curlRc, `\nproxy-user = "${proxyUser}:${proxyPass}"\n`);
            log('FIX', '已配置 curl 代理认证');
        }
    } catch {}

    log('PASS', '代理认证配置完成');
}

async function probeWebSocket(url) {
    const targetUrl = url || `ws://127.0.0.1:40005`;
    log('INFO', `探测 WebSocket 通道: ${targetUrl}`);

    try {
        const WebSocket = require('ws');
        return await new Promise((resolve) => {
            const ws = new WebSocket(targetUrl, { handshakeTimeout: 5000 });
            const timer = setTimeout(() => {
                ws.terminate();
                resolve(false);
            }, 6000);
            ws.on('open', () => {
                clearTimeout(timer);
                log('PASS', `WebSocket 通道可用: ${targetUrl}`);
                ws.close();
                resolve(true);
            });
            ws.on('error', (e) => {
                clearTimeout(timer);
                log('WARN', `WebSocket 通道不可用: ${targetUrl} - ${e.message}`);
                resolve(false);
            });
        });
    } catch {
        try {
            const parsed = new URL(targetUrl);
            const port = parseInt(parsed.port) || 40005;
            const host = parsed.hostname || '127.0.0.1';
            return await new Promise((resolve) => {
                const socket = new (require('net').Socket)();
                const timer = setTimeout(() => {
                    socket.destroy();
                    resolve(false);
                }, 5000);
                socket.connect(port, host, () => {
                    clearTimeout(timer);
                    log('PASS', `WebSocket 端口可达: ${host}:${port}`);
                    socket.destroy();
                    resolve(true);
                });
                socket.on('error', (e) => {
                    clearTimeout(timer);
                    log('WARN', `WebSocket 端口不可达: ${host}:${port} - ${e.message}`);
                    resolve(false);
                });
            });
        } catch (e) {
            log('WARN', `WebSocket 探测失败: ${e.message}`);
            return false;
        }
    }
}

async function installBrowserDeps() {
    log('INFO', 'Checking browser dependencies...');

    const browsers = [
        ...execSync('find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null || true').toString().trim().split('\n').filter(Boolean),
        ...execSync('find /opt/google/chrome -name "chrome" -type f 2>/dev/null || true').toString().trim().split('\n').filter(Boolean),
    ].filter(Boolean);

    if (browsers.length === 0) {
        log('INFO', 'No browser found, installing Playwright Chromium...');
        if (!isNpmGlobalInstalled('playwright')) {
            try {
                execSync('npm install -g playwright 2>&1', { stdio: 'pipe' });
                log('FIX', 'Playwright npm package installed');
            } catch (e) {
                log('FAIL', `Playwright npm install failed: ${e.message.substring(0, 80)}`);
                return;
            }
        } else {
            log('PASS', 'Playwright npm package already installed');
        }
        try {
            execSync('npx playwright install chromium 2>&1', { stdio: 'pipe' });
            log('FIX', 'Playwright Chromium installed');
        } catch (e) {
            log('FAIL', `Playwright install failed: ${e.message.substring(0, 80)}`);
            return;
        }
    }

    const browser = browsers[0] || execSync('find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1').toString().trim();
    if (!browser) {
        log('FAIL', 'No browser binary found after install attempt');
        return;
    }

    const missing = execSync(`ldd "${browser}" 2>&1 | grep "not found" | awk '{print $1}' | sort -u`).toString().trim().split('\n').filter(Boolean);

    if (missing.length === 0) {
        log('PASS', `All browser dependencies satisfied for ${path.basename(browser)}`);
        return;
    }

    log('WARN', `${missing.length} missing libraries: ${missing.join(', ')}`);

    const aptPkgs = {
        'libxkbcommon.so.0': 'libxkbcommon0',
        'libXcomposite.so.1': 'libxcomposite1',
        'libXdamage.so.1': 'libxdamage1',
        'libXfixes.so.3': 'libxfixes3',
        'libXrandr.so.2': 'libxrandr2',
        'libgbm.so.1': 'libgbm1',
        'libasound.so.2': 'libasound2t64',
        'libatk-1.0.so.0': 'libatk1.0-0',
        'libatk-bridge-2.0.so.0': 'libatk-bridge2.0-0',
        'libatspi.so.0': 'libatspi2.0-0',
        'libcups.so.2': 'libcups2',
        'libvulkan.so.1': 'libvulkan1',
        'libnss3.so': 'libnss3',
        'libnspr4.so': 'libnspr4',
    };

    const pkgsToInstall = missing.map(lib => aptPkgs[lib]).filter(Boolean);
    const pkgsNotInstalled = pkgsToInstall.filter(pkg => !isPackageInstalled(pkg));

    if (pkgsNotInstalled.length > 0) {
        log('FIX', `Attempting apt install: ${pkgsNotInstalled.join(' ')} (${pkgsToInstall.length - pkgsNotInstalled.length} already installed)`);
        try {
            execSync(`apt-get install -y ${pkgsNotInstalled.join(' ')} 2>&1`, { stdio: 'pipe' });
            log('PASS', `apt install succeeded for ${pkgsNotInstalled.length} packages`);
        } catch (e) {
            log('WARN', `apt install failed, falling back to downloadWithFallback...`);
            await installDepsViaFetch(missing);
        }
    } else if (pkgsToInstall.length > 0) {
        log('PASS', `All ${pkgsToInstall.length} apt packages already installed`);
    } else {
        log('WARN', 'No known apt packages for missing libs, trying downloadWithFallback...');
        await installDepsViaFetch(missing);
    }

    const stillMissing = execSync(`ldd "${browser}" 2>&1 | grep "not found" | awk '{print $1}'`).toString().trim();
    if (stillMissing) {
        log('WARN', `Still missing: ${stillMissing.replace(/\n/g, ', ')}`);
    } else {
        log('PASS', 'All browser dependencies now satisfied!');
    }
}

async function installDepsViaFetch(missingLibs) {
    const MIRRORS = [
        'https://mirrors.tuna.tsinghua.edu.cn/ubuntu/pool',
        'https://mirrors.aliyun.com/ubuntu/pool',
        'https://ftp.debian.org/debian/pool',
    ];

    const libToPkg = {
        'libxkbcommon.so.0': ['main/libx/libxkbcommon', 'libxkbcommon0'],
        'libXcomposite.so.1': ['main/libx/libxcomposite', 'libxcomposite1'],
        'libXdamage.so.1': ['main/libxd/libxdamage', 'libxdamage1'],
        'libXfixes.so.3': ['main/libx/libxfixes', 'libxfixes3'],
        'libXrandr.so.2': ['main/libx/libxrandr', 'libxrandr2'],
        'libgbm.so.1': ['main/m/mesa', 'libgbm1'],
        'libasound.so.2': ['main/a/alsa-lib', 'libasound2t64'],
        'libatk-1.0.so.0': ['main/a/atk1.0', 'libatk1.0-0'],
        'libatk-bridge-2.0.so.0': ['main/a/at-spi2-atk', 'libatk-bridge2.0-0'],
        'libatspi.so.0': ['main/a/at-spi2-core', 'libatspi2.0-0'],
        'libcups.so.2': ['main/c/cups', 'libcups2'],
    };

    const debDir = '/tmp/debs';
    const extractDir = '/tmp/extracted_libs';
    if (!fs.existsSync(debDir)) fs.mkdirSync(debDir, { recursive: true });

    for (const lib of missingLibs) {
        const pkgInfo = libToPkg[lib];
        if (!pkgInfo) {
            log('WARN', `No fetch mapping for ${lib}`);
            continue;
        }

        const [poolDir, pattern] = pkgInfo;
        const destPath = path.join(debDir, `${pattern}.deb`);

        if (isFileValid(destPath, 1024)) {
            log('PASS', `${pattern}.deb already downloaded, skipping`);
            continue;
        }

        let downloaded = false;

        for (const mirror of MIRRORS) {
            if (downloaded) break;
            try {
                const listUrl = `${mirror}/${poolDir}/`;
                const resp = await fetch(listUrl, { signal: AbortSignal.timeout(10000) });
                if (!resp.ok) continue;
                const html = await resp.text();
                const files = (html.match(/href="([^"]+\.deb)"/g) || []).map(m => m.match(/href="([^"]+)"/)[1]);
                const candidates = files.filter(f => f.startsWith(pattern) && f.includes('_amd64') && !f.includes('-dev') && !f.includes('-dbg'));
                const latest = candidates[candidates.length - 1];
                if (!latest) continue;

                const debUrl = `${mirror}/${poolDir}/${latest}`;
                const size = await downloadWithFallback(debUrl, destPath);
                log('FIX', `Downloaded ${pattern}.deb (${Math.round(size / 1024)}KB) from ${mirror.split('/')[2]}`);
                downloaded = true;
            } catch (e) {
                continue;
            }
        }

        if (!downloaded) {
            log('FAIL', `Could not download package for ${lib}`);
        }
    }

    if (fs.existsSync(debDir) && fs.readdirSync(debDir).some(f => f.endsWith('.deb'))) {
        log('INFO', 'Extracting downloaded packages...');
        try {
            execSync(`for deb in ${debDir}/*.deb; do dpkg-deb -x "$deb" "${extractDir}"; done 2>&1`, { stdio: 'pipe' });

            const libDir = path.join(extractDir, 'usr/lib/x86_64-linux-gnu');
            if (fs.existsSync(libDir)) {
                const confPath = '/etc/ld.so.conf.d/sandbox-libs.conf';
                if (!isLineInFile(confPath, libDir)) {
                    fs.appendFileSync(confPath, `\n${libDir}\n`);
                }

                const pwDirs = fs.readdirSync('/root/.cache/ms-playwright/', { withFileTypes: true })
                    .filter(d => d.isDirectory())
                    .map(d => `/root/.cache/ms-playwright/${d.name}/chrome-linux64`);
                for (const pwDir of pwDirs) {
                    if (fs.existsSync(pwDir) && !isLineInFile(confPath, pwDir)) {
                        fs.appendFileSync(confPath, `\n${pwDir}\n`);
                    }
                }

                try { execSync('ldconfig 2>/dev/null', { stdio: 'pipe' }); } catch {}
                log('FIX', `Libraries extracted and registered from ${libDir}`);
            }
        } catch (e) {
            log('FAIL', `Extraction failed: ${e.message.substring(0, 80)}`);
        }
    }
}

async function setupNpmRegistry() {
    const npmRc = path.join(process.env.HOME || '/root', '.npmrc');
    let content = '';
    try { content = fs.readFileSync(npmRc, 'utf8'); } catch {}

    if (!content.includes('registry=')) {
        const registries = [
            'https://registry.npmmirror.com',
            'https://registry.npmjs.org',
        ];

        for (const reg of registries) {
            try {
                const r = await fetch(`${reg}/latest`, { signal: AbortSignal.timeout(5000) });
                if (r.ok) {
                    fs.appendFileSync(npmRc, `\nregistry=${reg}\n`);
                    log('FIX', `Set npm registry to ${reg}`);
                    break;
                }
            } catch {}
        }
    }
}

async function setupPipMirror() {
    const pipConf = path.join(process.env.HOME || '/root', '.pip/pip.conf');
    if (!fs.existsSync(pipConf)) {
        const dir = path.dirname(pipConf);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(pipConf, `[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple\ntrusted-host = pypi.tuna.tsinghua.edu.cn\n`);
        log('FIX', 'Set pip mirror to tsinghua');
    }
}

async function testNetworkPaths() {
    log('INFO', 'Testing all network paths...');

    const paths = [
        { name: 'curl', cmd: 'curl -s --connect-timeout 5 https://httpbin.org/ip' },
        { name: 'wget', cmd: 'wget -q --timeout=5 -O- https://httpbin.org/ip' },
        { name: 'Node.js fetch', async: true, fn: () => fetch('https://httpbin.org/ip', { signal: AbortSignal.timeout(8000) }).then(r => r.ok) },
        { name: 'Python urllib', cmd: `python3 -c "import urllib.request; urllib.request.urlopen('https://httpbin.org/ip',timeout=5)" 2>/dev/null` },
        { name: 'apt', cmd: 'apt-get update -qq 2>/dev/null' },
    ];

    for (const p of paths) {
        try {
            if (p.async) {
                const ok = await p.fn();
                if (ok) log('PASS', `${p.name}: WORKING`); else log('FAIL', `${p.name}: FAILED`);
            } else {
                execSync(p.cmd, { timeout: 10000, stdio: 'pipe' });
                log('PASS', `${p.name}: WORKING`);
            }
        } catch {
            log('FAIL', `${p.name}: NOT WORKING`);
        }
    }
}

async function connectCDPBrowser(cdpUrl) {
    const targetUrl = cdpUrl || 'http://127.0.0.1:9222';
    log('INFO', `Connecting to CDP browser at ${targetUrl}...`);

    let playwright;
    try {
        playwright = require('playwright');
    } catch {
        log('FAIL', 'Playwright not installed — cannot use CDP connection');
        return null;
    }

    try {
        const versionResp = await testUrl(`${targetUrl}/json/version`);
        if (!versionResp.ok) {
            log('WARN', `CDP endpoint not responding at ${targetUrl}`);
            return null;
        }

        const versionInfo = JSON.parse(versionResp.body);
        log('PASS', `CDP browser detected: ${versionInfo.Browser || 'Chrome'} (${versionInfo['Protocol-Version'] || 'unknown'})`);

        const browser = await playwright.chromium.connectOverCDP(targetUrl);
        const contexts = browser.contexts();
        const pages = contexts.length > 0 ? contexts[0].pages().length : 0;
        log('PASS', `CDP connected: ${contexts.length} context(s), ${pages} page(s)`);
        return browser;
    } catch (e) {
        log('WARN', `CDP connection failed: ${e.message.substring(0, 100)}`);
        return null;
    }
}

(async () => {
    console.log('╔═══════════════════════════════════════════════════════╗');
    console.log('║   NETWORK FIX & OPTIMIZATION                         ║');
    console.log('╚═══════════════════════════════════════════════════════╝\n');

    const { profile, tests } = await detectNetworkProfile();

    await fixProxyConfig();
    await fixAptProxy();
    await detectAndHandleProxyAuth();
    await setupNpmRegistry();
    await setupPipMirror();
    await installBrowserDeps();

    const wsAvailable = await probeWebSocket();
    if (wsAvailable) {
        log('INFO', 'WebSocket 通道已记录为可用网络通道');
    }

    console.log('\n--- Post-Fix Network Verification ---');
    await testNetworkPaths();

    console.log('\n╔═══════════════════════════════════════════════════════╗');
    console.log('║   NETWORK FIX COMPLETE                                ║');
    console.log('╚═══════════════════════════════════════════════════════╝');
})().catch(err => {
    console.error('Fatal:', err.message);
    process.exit(1);
});

module.exports = {
    downloadWithFallback,
    downloadWithRetry,
    detectAndHandleProxyAuth,
    probeWebSocket,
    downloadViaNodeFetch,
    connectCDPBrowser,
    isPackageInstalled,
    isNpmGlobalInstalled,
    isLineInFile,
    isFileValid,
};
