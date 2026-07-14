#!/usr/bin/env node

/**
 * Postinstall script — downloads the prebuilt zcompress binary from GitHub Releases.
 * Falls back gracefully if binary can't be fetched.
 */

import { createWriteStream, existsSync, chmodSync, mkdirSync, unlinkSync, readFileSync } from 'node:fs';
import { get } from 'node:https';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pipeline } from 'node:stream/promises';

const __dirname = dirname(fileURLToPath(import.meta.url));
const BIN_DIR = join(__dirname, 'bin');
const REPO = 'luochuan2008/zcompress';

// Read package version dynamically to avoid manual sync bugs.
const pkgJson = JSON.parse(readFileSync(join(__dirname, 'package.json'), 'utf8'));
const VERSION = pkgJson.version;

const PLATFORM_MAP = {
  'darwin-arm64': 'zcompress-macos-arm64',
  'darwin-x64': 'zcompress-macos-x64',
  'linux-x64': 'zcompress-linux-x64',
  'win32-x64': 'zcompress-windows-x64.exe',
};

function getPlatformKey() {
  const os = process.platform;
  const arch = process.arch === 'x64' ? 'x64' : process.arch === 'arm64' ? 'arm64' : process.arch;
  return `${os}-${arch}`;
}

function getBinaryName() {
  return PLATFORM_MAP[getPlatformKey()] || null;
}

function request(url) {
  return new Promise((resolve, reject) => {
    get(url, {
      headers: {
        'User-Agent': 'zcompress-vite-plugin-install',
        Accept: 'application/vnd.github+json',
      },
    }, (res) => resolve(res)).on('error', reject);
  });
}

async function fetchJson(url) {
  const res = await request(url);
  if (res.statusCode !== 200) {
    throw new Error(`HTTP ${res.statusCode}`);
  }
  const chunks = [];
  for await (const chunk of res) chunks.push(chunk);
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

async function downloadToFile(url, destPath) {
  const res = await request(url);

  // Follow redirect (GitHub release assets usually 302)
  if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
    return downloadToFile(res.headers.location, destPath);
  }

  if (res.statusCode !== 200) {
    throw new Error(`HTTP ${res.statusCode}`);
  }

  const file = createWriteStream(destPath);
  await pipeline(res, file);
}

async function resolveFallbackAssetUrl(binaryName) {
  // Fallback strategy: use latest release asset for this platform when current version asset is missing.
  const latest = await fetchJson(`https://api.github.com/repos/${REPO}/releases/latest`);
  const asset = (latest.assets || []).find((a) => a.name === binaryName);
  if (!asset?.browser_download_url) {
    throw new Error('Latest release has no matching asset');
  }
  return asset.browser_download_url;
}

async function downloadBinary() {
  const binaryName = getBinaryName();
  if (!binaryName) {
    console.log(`[zcompress] ⚠ Unsupported platform: ${getPlatformKey()}. Build from source: zig build install`);
    return false;
  }

  const destPath = join(BIN_DIR, process.platform === 'win32' ? 'zcompress.exe' : 'zcompress');

  // Skip if already downloaded
  if (existsSync(destPath)) {
    console.log(`[zcompress] ✓ Binary already installed: ${destPath}`);
    return true;
  }

  mkdirSync(BIN_DIR, { recursive: true });

  const versionedUrl = `https://github.com/${REPO}/releases/download/v${VERSION}/${binaryName}`;
  const tried = [];

  // Attempt 1: exact npm version
  try {
    tried.push(versionedUrl);
    console.log(`[zcompress] ↓ Downloading ${versionedUrl} ...`);
    await downloadToFile(versionedUrl, destPath);

    if (process.platform !== 'win32') chmodSync(destPath, 0o755);
    console.log(`[zcompress] ✓ Binary installed: ${destPath}`);
    return true;
  } catch (err) {
    // cleanup partial
    try { unlinkSync(destPath); } catch {}

    // If 404 or similar, try latest release as fallback
    const msg = String(err?.message || err);
    if (!msg.includes('404')) {
      console.log(`[zcompress] ⚠ Download failed (${msg}).`);
    } else {
      console.log(`[zcompress] ⚠ Asset missing for v${VERSION}: ${binaryName}`);
    }
  }

  // Attempt 2: latest release fallback
  try {
    const latestAssetUrl = await resolveFallbackAssetUrl(binaryName);
    tried.push(latestAssetUrl);
    console.log(`[zcompress] ↓ Falling back to latest release asset: ${latestAssetUrl}`);
    await downloadToFile(latestAssetUrl, destPath);

    if (process.platform !== 'win32') chmodSync(destPath, 0o755);
    console.log(`[zcompress] ✓ Binary installed from latest release: ${destPath}`);
    return true;
  } catch (err) {
    try { unlinkSync(destPath); } catch {}
    console.log(`[zcompress] ⚠ Fallback download failed (${err.message}).`);
    console.log('[zcompress] Tried URLs:');
    for (const u of tried) console.log(`  - ${u}`);
    console.log('[zcompress] ℹ Build from source: cd zcompress && zig build -Doptimize=ReleaseFast');
    return false;
  }
}

// Run download, but don't fail install if it doesn't work
downloadBinary().catch((err) => {
  console.log(`[zcompress] ⚠ Binary download skipped (${err.message}).`);
  console.log('[zcompress] ℹ Install it manually and set plugin option `binaryPath`.');
});
