#!/usr/bin/env node
/**
 * Dependency Fetcher for Sandbox Environments
 * Downloads missing Chrome/Chromium system library packages
 * using Node.js fetch() when CLI networking is blocked.
 * 
 * Usage:
 *   node scripts/fetch-deps.js [--mirror MIRROR_URL] [--output-dir DIR]
 *   node scripts/fetch-deps.js --list-only        # Just show what would be downloaded
 *   node scripts/fetch-deps.js --extract          # Download + extract automatically
 */

const fs = require('fs');
const path = require('path');

// Configuration
const DEFAULT_MIRROR = 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu/pool';
const DEFAULT_OUTPUT_DIR = '/tmp/debs';
const DEFAULT_EXTRACT_DIR = '/tmp/extracted_libs';

// Parse args
const args = process.argv.slice(2);
const opts = {
  mirror: DEFAULT_MIRROR,
  outputDir: DEFAULT_OUTPUT_DIR,
  extractDir: DEFAULT_EXTRACT_DIR,
  listOnly: false,
  autoExtract: false,
};

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--mirror' && args[i+1]) opts.mirror = args[++i];
  if (args[i] === '--output-dir' && args[i+1]) opts.outputDir = args[++i];
  if (args[i] === '--list-only') opts.listOnly = true;
  if (args[i] === '--extract') opts.autoExtract = true;
}

// Package definitions: [pool_subdir, name_pattern, output_filename, description]
const PACKAGES = [
  ['main/libx/libxkbcommon',    'libxkbcommon0',          'libxkbcommon0.deb',       'XKB keyboard common'],
  ['main/libx/libxcomposite',   'libxcomposite1',         'libXcomposite1.deb',      'X Composite extension'],
  ['main/libx/libxdamage',     'libxdamage1',             'libXdamage1.deb',        'X Damage extension'],
  ['main/libx/libxfixes',      'libxfixes3',              'libXfixes3.deb',         'X Fixes extension'],
  ['main/libx/libxrandr',      'libxrandr2',              'libXrandr2.deb',         'X RandR extension'],
  ['main/m/mesa',              'libgbm1',                  'libgbm1.deb',            'Mesa GBM buffer management'],
  ['main/a/alsa-lib',          'libasound2t64',           'libasound2t64.deb',      'ALSA sound library'],
];

// Alternative mirrors to try if primary fails
const FALLBACK_MIRRORS = [
  'https://mirrors.aliyun.com/ubuntu/pool',
  'https://ftp.debian.org/debian/pool',
];

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function listDirectory(url) {
  const resp = await fetch(url, { signal: AbortSignal.timeout(10000) });
  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
  const html = await resp.text();
  return (html.match(/href="([^"]+\.deb)"/g) || [])
    .map(m => m.match(/href="([^"]+)"/)[1]);
}

async function findLatest(baseUrl, pattern) {
  try {
    const files = await listDirectory(baseUrl);
    // Filter: matches pattern, amd64, not dev/not dbg package
    const candidates = files.filter(f => 
      f.startsWith(pattern) && 
      f.includes('_amd64') && 
      !f.includes('-dev') && 
      !f.includes('-dbg')
    );
    // Sort by version (last = latest typically)
    return candidates[candidates.length - 1] || null;
  } catch(e) {
    return null;
  }
}

async function downloadFile(url, destPath) {
  const dir = path.dirname(destPath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  
  const resp = await fetch(url, { signal: AbortSignal.timeout(30000) });
  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
  
  const buf = Buffer.from(await resp.arrayBuffer());
  fs.writeFileSync(destPath, buf);
  return buf.length;
}

async function extractDeb(debPath, extractDir) {
  if (!fs.existsSync(extractDir)) fs.mkdirSync(extractDir, { recursive: true });
  const { execSync } = require('child_process');
  try {
    execSync(`dpkg-deb -x "${debPath}" "${extractDir}"`, { stdio: 'pipe' });
    return true;
  } catch(e) {
    return false;
  }
}

function registerLibraries(extractDir) {
  const libDir = path.join(extractDir, 'usr/lib/x86_64-linux-gnu');
  if (!fs.existsSync(libDir)) return;
  
  // Add to ld.so.conf.d
  const confPath = '/etc/ld.so.conf.d/sandbox-libs.conf';
  let existing = '';
  try { existing = fs.readFileSync(confPath, 'utf8'); } catch {}
  
  if (!existing.includes(libDir)) {
    fs.appendFileSync(confPath, `\n${libDir}\n`);
  }
  
  // Also add Playwright chrome dir
  const pwDirs = fs.readdirSync('/root/.cache/ms-playwright/', { withFileTypes: true })
    .filter(d => d.isDirectory() && d.name.startsWith('chromium'))
    .map(d => `/root/.cache/ms-playwright/${d.name}/chrome-linux64`);
  
  for (const pwDir of pwDirs) {
    if (!existing.includes(pwDir)) {
      fs.appendFileSync(confPath, `\n${pwDir}\n`);
    }
  }
  
  // Create version-less symlinks
  if (fs.existsSync(libDir)) {
    const soFiles = fs.readdirSync(libDir).filter(f => f.endsWith('.so') && f.includes('.so.'));
    for (const f of soFiles) {
      const fullPath = path.join(libDir, f);
      let base = f.replace(/\.[0-9]+$/, '');
      while (base !== f && !fs.existsSync(path.join(libDir, base))) {
        try { fs.symlinkSync(f, path.join(libDir, base)); } catch {}
        break;
      }
    }
  }
  
  // Run ldconfig (may fail in containers, that's OK)
  try { require('child_process').execSync('ldconfig 2>/dev/null', { stdio: 'pipe' }); } catch {}
}

// Main
(async () => {
  console.log('=== Sandbox Dependency Fetcher ===\n');
  console.log(`Mirror: ${opts.mirror}`);
  console.log(`Output: ${opts.outputDir}`);
  console.log('');

  if (!fs.existsSync(opts.outputDir)) fs.mkdirSync(opts.outputDir, { recursive: true });

  let successCount = 0;
  let failCount = 0;

  for (const [poolDir, pattern, outputName, desc] of PACKAGES) {
    const baseUrl = `${opts.mirror}/${poolDir}/`;
    process.stdout.write(`[${desc.padEnd(30)}] ${pattern.padEnd(20)} `);

    if (opts.listOnly) {
      const latest = await findLatest(baseUrl, pattern);
      if (latest) {
        console.log(`FOUND: ${latest}`);
      } else {
        console.log('NOT FOUND');
      }
      continue;
    }

    // Try primary mirror first
    let latest = null;
    let usedUrl = null;

    const mirrorsToTry = [baseUrl, ...FALLBACK_MIRRORS.map(m => `${m}/${poolDir}/`)];
    
    for (const url of mirrorsToTry) {
      latest = await findLatest(url, pattern);
      if (latest) {
        usedUrl = `${url}${latest}`;
        break;
      }
    }

    if (!latest) {
      console.log('FAIL (not found on any mirror)');
      failCount++;
      continue;
    }

    const destPath = path.join(opts.outputDir, outputName);
    try {
      const size = await downloadFile(usedUrl, destPath);
      const sizeKB = Math.round(size / 1024);
      console.log(`OK (${sizeKB}KB)`);
      successCount++;

      if (opts.autoExtract) {
        await extractDeb(destPath, opts.extractDir);
      }
    } catch(e) {
      console.log(`FAIL (${e.message.substring(0, 40)})`);
      failCount++;
    }

    await sleep(200); // Be nice to the mirror
  }

  console.log('');
  console.log(`Results: ${successCount} downloaded, ${failCount} failed`);

  if (opts.autoExtract && successCount > 0) {
    console.log('\nRegistering libraries...');
    registerLibraries(opts.extractDir);
    console.log('Done! Libraries registered.');
    console.log('\nTo use: export LD_LIBRARY_PATH="' + 
      path.join(opts.extractDir, 'usr/lib/x86_64-linux-gnu') +
      ':$LD_LIBRARY_PATH"');
  }
})().catch(err => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
