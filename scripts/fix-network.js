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

async function installBrowserDeps() {
    log('INFO', 'Checking browser dependencies...');
    
    const browsers = [
        ...execSync('find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null || true').toString().trim().split('\n').filter(Boolean),
        ...execSync('find /opt/google/chrome -name "chrome" -type f 2>/dev/null || true').toString().trim().split('\n').filter(Boolean),
    ].filter(Boolean);

    if (browsers.length === 0) {
        log('INFO', 'No browser found, installing Playwright Chromium...');
        try {
            execSync('npm install -g playwright 2>&1', { stdio: 'pipe' });
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
    
    if (pkgsToInstall.length > 0) {
        log('FIX', `Attempting apt install: ${pkgsToInstall.join(' ')}`);
        try {
            execSync(`apt-get install -y ${pkgsToInstall.join(' ')} 2>&1`, { stdio: 'pipe' });
            log('PASS', `apt install succeeded for ${pkgsToInstall.length} packages`);
        } catch (e) {
            log('WARN', `apt install failed, falling back to Node.js fetch...`);
            await installDepsViaFetch(missing);
        }
    } else {
        log('WARN', 'No known apt packages for missing libs, trying Node.js fetch...');
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
                const destPath = path.join(debDir, `${pattern}.deb`);
                const size = await downloadViaNodeFetch(debUrl, destPath);
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
                let existing = '';
                try { existing = fs.readFileSync(confPath, 'utf8'); } catch {}
                if (!existing.includes(libDir)) {
                    fs.appendFileSync(confPath, `\n${libDir}\n`);
                }
                
                const pwDirs = fs.readdirSync('/root/.cache/ms-playwright/', { withFileTypes: true })
                    .filter(d => d.isDirectory())
                    .map(d => `/root/.cache/ms-playwright/${d.name}/chrome-linux64`);
                for (const pwDir of pwDirs) {
                    if (fs.existsSync(pwDir) && !existing.includes(pwDir)) {
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

(async () => {
    console.log('╔═══════════════════════════════════════════════════════╗');
    console.log('║   NETWORK FIX & OPTIMIZATION                         ║');
    console.log('╚═══════════════════════════════════════════════════════╝\n');

    const { profile, tests } = await detectNetworkProfile();
    
    await fixProxyConfig();
    await fixAptProxy();
    await setupNpmRegistry();
    await setupPipMirror();
    await installBrowserDeps();
    
    console.log('\n--- Post-Fix Network Verification ---');
    await testNetworkPaths();

    console.log('\n╔═══════════════════════════════════════════════════════╗');
    console.log('║   NETWORK FIX COMPLETE                                ║');
    console.log('╚═══════════════════════════════════════════════════════╝');
})().catch(err => {
    console.error('Fatal:', err.message);
    process.exit(1);
});
