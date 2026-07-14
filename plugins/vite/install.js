#!/usr/bin/env node

/**
 * Postinstall script — downloads the prebuilt zcompress binary from GitHub Releases.
 * Falls back gracefully if the binary can't be downloaded (e.g. air-gapped, unsupported platform).
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
  'darwin-arm64':  'zcompress-macos-arm64',
  'darwin-x64':    'zcompress-macos-x64',
  'linux-x64':     'zcompress-linux-x64',
  'win32-x64':     'zcompress-windows-x64.exe',
};

function getPlatformKey() {
  const os = process.platform;
  const arch = process.arch === 'x64' ? 'x64' : process.arch === 'arm64' ? 'arm64' : process.arch;
  return `${os}-${arch}`;
}

function getBinaryName() {
  const key = getPlatformKey();
  return PLATFORM_MAP[key] || null;
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

  const url = `https://github.com/${REPO}/releases/download/v${VERSION}/${binaryName}`;
  console.log(`[zcompress] ↓ Downloading ${url} ...`);

  try {
    mkdirSync(BIN_DIR, { recursive: true });

    await new Promise((resolve, reject) => {
      const file = createWriteStream(destPath);
      get(url, (response) => {
        // Follow redirects
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          get(response.headers.location, (redirectRes) => {
            pipeline(redirectRes, file).then(resolve).catch(reject);
          }).on('error', reject);
          return;
        }
        if (response.statusCode !== 200) {
          file.close();
          unlinkSync(destPath);
          reject(new Error(`HTTP ${response.statusCode}`));
          return;
        }
        pipeline(response, file).then(resolve).catch(reject);
      }).on('error', reject);
    });

    // Make executable on Unix
    if (process.platform !== 'win32') {
      chmodSync(destPath, 0o755);
    }

    console.log(`[zcompress] ✓ Binary installed: ${destPath}`);
    return true;
  } catch (err) {
    console.log(`[zcompress] ⚠ Could not download binary (${err.message}). Build from source: cd zcompress && zig build install`);
    // Clean up partial download
    try { unlinkSync(destPath); } catch (_) { /* ignore */ }
    return false;
  }
}

// Run download, but don't fail install if it doesn't work
downloadBinary().catch(() => {
  console.log('[zcompress] ℹ Binary download skipped. The plugin requires the zcompress CLI.');
  console.log('[zcompress] ℹ Install it via: brew install zcompress  OR  zig build install');
});
