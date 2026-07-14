#!/usr/bin/env node

/**
 * Verify GitHub release assets exist BEFORE npm publish.
 *
 * This prevents publishing broken npm versions where postinstall binary download returns 404.
 */

import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { request } from 'node:https';

const __dirname = dirname(fileURLToPath(import.meta.url));
const pkg = JSON.parse(readFileSync(join(__dirname, 'package.json'), 'utf8'));

const REPO = 'luochuan2008/zcompress';
const VERSION = pkg.version;
const TAG = `v${VERSION}`;

const warnOnly = process.argv.includes('--warn-only');

const ASSETS = [
  'zcompress-macos-arm64',
  'zcompress-macos-x64',
  'zcompress-linux-x64',
  'zcompress-windows-x64.exe',
];

function head(url) {
  return new Promise((resolve) => {
    const req = request(url, {
      method: 'HEAD',
      headers: {
        'User-Agent': 'zcompress-vite-plugin-verify',
      },
    }, (res) => {
      resolve(res.statusCode || 0);
    });

    req.setTimeout(8000, () => {
      req.destroy(new Error('timeout'));
    });

    req.on('error', () => resolve(0));
    req.end();
  });
}

async function main() {
  console.log(`[verify-release-assets] Checking ${REPO} ${TAG} ...`);

  const missing = [];

  for (const asset of ASSETS) {
    const url = `https://github.com/${REPO}/releases/download/${TAG}/${asset}`;
    const code = await head(url);
    // GitHub usually returns 302 for release assets, then CDN 200.
    const ok = code === 200 || code === 302;

    if (ok) {
      console.log(`  ✅ ${asset} (${code})`);
    } else {
      console.log(`  ❌ ${asset} (${code || 'ERR'})`);
      missing.push(url);
    }
  }

  if (missing.length > 0) {
    const lines = [
      '\n[verify-release-assets] Missing required release assets.',
      '[verify-release-assets] Upload binaries to GitHub Release first for best UX.',
      ...missing.map((u) => `  - ${u}`),
    ];
    for (const l of lines) console.error(l);

    if (warnOnly) {
      console.error('[verify-release-assets] WARN ONLY mode: continuing publish.');
      process.exit(0);
    }

    process.exit(1);
  }

  console.log('\n[verify-release-assets] All required assets exist. Safe to publish.');
}

main().catch((err) => {
  console.error('[verify-release-assets] Unexpected error:', err?.message || err);
  process.exit(1);
});
